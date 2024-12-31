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
