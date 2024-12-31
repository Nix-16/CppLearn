## 线程池
线程池（Thread Pool） 是一种用于管理多个线程的设计模式。它通过预先创建一定数量的线程，将任务分配给这些线程进行执行，避免频繁创建和销毁线程所带来的开销，提高程序的执行效率。

### 1. 为什么需要线程池？
1. 线程创建与销毁开销大
* 每次创建和销毁线程都会消耗系统资源。
* 频繁创建和销毁线程会影响程序性能。
2. 线程数量不可控
* 如果每个任务都单独创建一个线程，线程数可能会迅速增加，导致系统资源耗尽。
3. 任务调度困难
* 线程管理和任务调度会变得复杂，容易出现死锁、资源争用 等问题。
4. 提高资源利用率
* 线程池复用线程，减少线程创建和销毁的开销。
* 有效控制线程的最大数量，防止系统过载。

### 2. 线程池的工作原理
在线程池中预先创建一组线程，新的任务被添加到一个任务队列中, 空闲线程从任务队列中取出任务进行执行, 线程执行任务，执行完毕后返回线程池，继续等待下一个任务, 在程序退出时，线程池安全地关闭，回收所有线程资源。

### 3. 线程池的核心组成
1. 任务队列
* 存储待执行的任务。
* 通常使用 std::queue 或 std::priority_queue。

2. 工作线程
* 线程池中实际执行任务的线程。
* 在空闲时等待任务到来。

3. 线程同步机制
* 使用 互斥锁（mutex） 保证线程安全地访问任务队列。
* 使用 条件变量（condition_variable） 控制线程等待和唤醒。

4. 任务提交接口
* 提供一个接口，允许外部将任务提交到线程池中。

5.  停止标志
* 用于指示线程池是否应该停止运行。


### 4. 一个最简单的线程池

* 工作线程（Worker Threads）
* 任务队列（Task Queue）
* 线程同步机制
* 任务提交接口
* 停止标志

```
#ifndef THREADPOOL_H
#define THREADPOOL_H

#include <iostream>
#include <vector>
#include <queue>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <functional>
#include <atomic>

class ThreadPool
{
public:
    ThreadPool(size_t numThreads);
    ~ThreadPool();

    // 添加任务到任务队列
    template <typename F, typename... Args>
    void enqueue(F &&f, Args &&...args);

private:
    void workerThread();  // 工作线程函数

    std::vector<std::thread> workers;        // 工作线程集合
    std::queue<std::function<void()>> tasks; // 任务队列

    std::mutex queueMutex;             // 任务队列互斥锁
    std::condition_variable condition; // 条件变量用于线程同步
    std::atomic<bool> stop;            // 停止线程池的标志
};

ThreadPool::ThreadPool(size_t numThreads) : stop(false)
{
    for (size_t i = 0; i < numThreads; ++i)
    {
        workers.emplace_back(&ThreadPool::workerThread, this);
    }
}

ThreadPool::~ThreadPool()
{
    {
        std::unique_lock<std::mutex> lock(queueMutex);
        stop = true;
    }
    condition.notify_all(); // 唤醒所有线程，确保它们能够退出
    for (std::thread &worker : workers)
    {
        if (worker.joinable())
        {
            worker.join();
        }
    }
}

template <typename F, typename... Args>
void ThreadPool::enqueue(F &&f, Args &&...args)
{
    {
        std::unique_lock<std::mutex> lock(queueMutex);
        tasks.emplace([func = std::forward<F>(f), ... args = std::forward<Args>(args)]() mutable
                      { func(args...); });
    }
    condition.notify_one(); // 唤醒一个工作线程
}

void ThreadPool::workerThread()
{
    while (true)
    {
        std::function<void()> task;
        {
            std::unique_lock<std::mutex> lock(queueMutex);
            condition.wait(lock, [this]
                           { return stop || !tasks.empty(); });
            if (stop && tasks.empty())
            {
                return;
            }
            task = std::move(tasks.front());
            tasks.pop();
        }

        // 执行任务
        task();
    }
}
#endif
```

### 5. 线程池的优化方向

1. 动态线程管理
* 根据任务数量动态调整线程池中的线程数量。
2. 任务优先级
* 使用优先级队列，优先执行高优先级任务。
3. 任务超时处理
* 如果任务长时间未完成，可以强制中断或丢弃。
4. 监控与统计
* 实时监控线程池状态、任务完成率、线程利用率等。

```
#include "ThreadPool.hpp"
int main()
{
    ThreadPool pool(4); // 创建一个包含 4 个线程的线程池

    // 提交 8 个任务到线程池
    for (int i = 0; i < 50; ++i)
    {
        pool.enqueue([i]
                     {     
            std::cout << "Task " << i << " is running in thread " 
                      << std::this_thread::get_id() << std::endl;
            std::this_thread::sleep_for(std::chrono::seconds(1)); });
    }

    std::cout << "All tasks have been enqueued." << std::endl;

    std::this_thread::sleep_for(std::chrono::seconds(20)); // 等待任务完成

    return 0;
}
```

```
#ifndef THREADPOOL_H
#define THREADPOOL_H

#include <iostream>
#include <vector>
#include <queue>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <functional>
#include <atomic>
#include <chrono>

class ThreadPool
{
public:
    ThreadPool(size_t numThreads);
    ~ThreadPool();

    template <typename F, typename... Args>
    void enqueue(F &&f, Args &&...args);

private:
    void workerThread();  // 工作线程函数
    void managerThread(); // 管理者线程函数

    std::vector<std::thread> workers;        // 工作线程集合
    std::thread manager;                     // 管理者线程
    std::queue<std::function<void()>> tasks; // 任务队列

    std::mutex queueMutex;             // 互斥锁
    std::condition_variable condition; // 条件变量
    std::atomic<bool> stop;            // 停止标志
    std::atomic<size_t> activeThreads; // 活跃线程数
    size_t minThreads;                 // 最小线程数
    size_t maxThreads;                 // 最大线程数
};

ThreadPool::ThreadPool(size_t numThreads)
    : stop(false), minThreads(numThreads), maxThreads(numThreads * 2), activeThreads(0)
{

    // 启动工作线程
    for (size_t i = 0; i < numThreads; ++i)
    {
        workers.emplace_back(&ThreadPool::workerThread, this);
    }

    // 启动管理者线程
    manager = std::thread(&ThreadPool::managerThread, this);
}

template <typename F, typename... Args>
void ThreadPool::enqueue(F &&f, Args &&...args)
{
    {
        std::unique_lock<std::mutex> lock(queueMutex);
        tasks.emplace([func = std::forward<F>(f), ... args = std::forward<Args>(args)]() mutable
                      { func(args...); });
    }
    condition.notify_one(); // 唤醒一个工作线程
}

// 工作线程逻辑
void ThreadPool::workerThread()
{
    while (true)
    {
        std::function<void()> task;
        {
            std::unique_lock<std::mutex> lock(queueMutex);
            condition.wait(lock, [this]
                           { return stop || !tasks.empty(); });
            if (stop && tasks.empty())
            {
                return;
            }
            task = std::move(tasks.front());
            tasks.pop();
            ++activeThreads;
        }

        // 执行任务
        task();
        --activeThreads;
    }
}

// 管理者线程逻辑
void ThreadPool::managerThread()
{
    while (!stop)
    {
        std::this_thread::sleep_for(std::chrono::seconds(5)); // 每5秒检查一次线程池状态

        std::unique_lock<std::mutex> lock(queueMutex);
        size_t queueSize = tasks.size();

        // 动态增加线程
        if (queueSize > workers.size() && workers.size() < maxThreads)
        {
            workers.emplace_back(&ThreadPool::workerThread, this);
            std::cout << "[Manager] 增加了一个线程，当前线程数: " << workers.size() << std::endl;
        }

        // 动态减少线程
        if (queueSize < workers.size() / 2 && workers.size() > minThreads)
        {
            stop = true; // 设置停止标志，等待线程退出
            condition.notify_one();
            std::cout << "[Manager] 减少了一个线程，当前线程数: " << workers.size() << std::endl;
        }
    }
}

// 析构函数：安全关闭线程池
ThreadPool::~ThreadPool()
{
    {
        std::unique_lock<std::mutex> lock(queueMutex);
        stop = true;
    }
    condition.notify_all(); // 唤醒所有线程

    for (std::thread &worker : workers)
    {
        if (worker.joinable())
        {
            worker.join();
        }
    }

    if (manager.joinable())
    {
        manager.join();
    }

    std::cout << "[ThreadPool] 线程池已安全关闭。" << std::endl;
}

#endif // THREADPOOL_H
```