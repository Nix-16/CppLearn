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