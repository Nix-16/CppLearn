# 设置 CMake 的最低版本要求
cmake_minimum_required(VERSION 3.10)

# 定义项目名称和版本
project(ThreadPoolProject VERSION 1.0 LANGUAGES CXX)

# 设置 C++ 标准
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# 将 main.cpp 添加为可执行文件
add_executable(ThreadPoolProject main.cpp)

# 将 ThreadPool.hpp 作为头文件包含路径
target_include_directories(ThreadPoolProject PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
