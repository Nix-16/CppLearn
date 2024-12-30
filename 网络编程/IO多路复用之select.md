# I/O 多路复用中的 `select`

## 1. `select` 的基本原理

`select` 是一种 I/O 多路复用技术，用于监控多个文件描述符（sockets、文件等）的状态变化。当某个文件描述符就绪时，`select` 会返回，我们可以针对就绪的文件描述符进行读写操作。`其实就是检测这些文件描述符对应的读写缓冲区的状态`：

- 读缓冲区：检测里边有没有数据，如果有数据该缓冲区对应的文件描述符就绪
- 写缓冲区：检测写缓冲区是否可以写(有没有容量)，如果有容量可以写，缓冲区对应的文件描述符就绪
- 读写异常：检测读写缓冲区是否有异常，如果有该缓冲区对应的文件描述符就绪

委托检测的文件描述符被遍历检测完毕之后，已就绪的这些满足条件的文件描述符会通过`select()`的参数分3个集合传出，程序猿得到这几个集合之后就可以分情况依次处理了。

### `select` 的函数原型：

```c
#include <sys/select.h>
#include <sys/time.h>
struct timeval {
    time_t      tv_sec;         /* seconds */
    suseconds_t tv_usec;        /* microseconds */
};

int select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);
```

**`nfds`**: 需要监视的最大文件描述符加1。

**`readfds`**: 用于检测是否可以读取数据的文件描述符集合。

**`writefds`**: 用于检测是否可以写数据的文件描述符集合。

**`exceptfds`**: 用于检测是否有异常的文件描述符集合。

**`timeout`**: 设置超时时间。为 `NULL` 时表示无限期阻塞；为 `{0, 0}` 时表示非阻塞；为其他值时表示阻塞一定时间。

### **`select`**函数返回值：

- 大于0：成功，返回集合中已就绪的文件描述符的总个数
- 等于-1：函数调用失败
- 等于0：超时，没有检测到就绪的文件描述符

另外初始化`fd_set`类型的参数还需要使用相关的一些列操作函数，具体如下：

```c++
// 将文件描述符fd从set集合中删除 == 将fd对应的标志位设置为0        
void FD_CLR(int fd, fd_set *set);
// 判断文件描述符fd是否在set集合中 == 读一下fd对应的标志位到底是0还是1
int  FD_ISSET(int fd, fd_set *set);  
// 将文件描述符fd添加到set集合中 == 将fd对应的标志位设置为1
void FD_SET(int fd, fd_set *set);
// 将set集合中, 所有文件文件描述符对应的标志位设置为0, 集合中没有添加任何文件描述符
void FD_ZERO(fd_set *set);
```

## 2. 使用流程

* 创建套接字，绑定和监听
* 初始化文件描述符集合
* 调用 `select` 进行阻塞或轮询
* 处理就绪的文件描述符
* 关闭连接（如有需要） 
* 反复调用 `select`

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <arpa/inet.h>
#include <netinet/in.h>

int main()
{
    // 1. 创建监听的fd
    int lfd = socket(AF_INET, SOCK_STREAM, 0);
    if(lfd == -1)
    {
        perror("socket error");
        return 0;
    }

    // 2. 绑定
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));

    addr.sin_family = AF_INET;
    addr.sin_port = htons(9999);
    addr.sin_addr.s_addr = INADDR_ANY;
    if (bind(lfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) 
    {
        perror("bind error");
        close(lfd);
        return 0;
    }

    // 3. 设置监听
    if(listen(lfd, 5) < 0)
    {
        perror("listen error");
        close(lfd);
        return 0;
    }

    // 将监听的fd的状态委托给内核检测
    int maxfd = lfd;
    // 初始化检测集合
    fd_set readset;
    fd_set readtemp;

    // 清零
    FD_ZERO(&readset);
    // 将监听的fd设置到读集合中
    FD_SET(lfd, &readset);

    // 通过select委托内核检测读集合的文件描述符状态，检测read缓冲区有没有数据
    // 如果没有数据select阻塞返回
    while(1)
    {
        readtemp = readset;
        int num = select(maxfd + 1, &readtemp, NULL, NULL, NULL);
        if (num < 0) {
            perror("select error");
            break;
        }

        // readset中的数据被内核修改，只保留了发生变化的文件描述符的标志位
        // 判断有没有新连接
        if(FD_ISSET(lfd, &readtemp))
        {
            // 接受连接请求
            struct sockaddr_in cliaddr;
            socklen_t clilen = sizeof(cliaddr);
            int cfd = accept(lfd, (struct sockaddr*)&cliaddr, &clilen);
            if (cfd < 0) {
                perror("accept error");
                continue;
            }

            // 得到有效的文件描述符
            // 通信的文件描述符添加到读集合
            FD_SET(cfd, &readset);

            // 重置最大的文件描述符
            maxfd = (cfd > maxfd) ? cfd : maxfd;
            printf("New connection established, cfd = %d\n", cfd);
        }

        // 没有新连接，进行通信
        for(int i = 0; i <= maxfd; ++i)
        {
            if(i != lfd && FD_ISSET(i, &readtemp))
            {
                // 接收数据
                char buf[1024] = {0};
                int len = read(i, buf, sizeof(buf));
                if(len == 0)
                {
                    printf("Client disconnected, fd = %d\n", i);
                    // 将检测的文件描述符从读集合中删除
                    FD_CLR(i, &readset);
                    close(i);
                }
                else if(len > 0)
                {
                    // 收到数据并回显
                    printf("Received from client: %s\n", buf);
                    write(i, buf, strlen(buf) + 1);
                }
                else
                {
                    perror("read error");
                    FD_CLR(i, &readset);
                    close(i);
                }
            }
        }
    }

    close(lfd);
    return 0;
}
```



## 3.`select` 的优缺点

### 优点：

- **跨平台**：`select` 是一种 POSIX 标准的 I/O 多路复用技术，支持 Linux、Unix、Windows 等操作系统。
- **简单易用**：相对其他 I/O 多路复用方式（如 `epoll`），`select` 的接口简单，适合学习和理解 I/O 多路复用的基本概念。

### `select` 的缺点

1. **文件描述符数量限制**：`select` 受到 `FD_SETSIZE` 的限制，通常为 1024，处理大量连接时效率低。
2. **性能瓶颈**：每次调用 `select` 时，需要遍历所有文件描述符，时间复杂度是 O(n)，随着连接数增加，性能下降。
3. **重复集合复制**：每次调用 `select` 都需要将文件描述符集合从用户空间复制到内核空间，增加开销。
4. **无法有效处理大量并发连接**：适用于少量连接，大量连接时性能不佳。
5. **不支持边缘触发**：只能在“水平触发”模式下工作，处理高并发流量时效率较低。
6. **非阻塞操作支持差**：虽然可以设置超时，但不直接支持高效的非阻塞操作。

### 小结：

`select` 是一种早期的 I/O 多路复用技术，适用于处理少量并发连接。但当面对大量连接时，它的性能瓶颈会变得尤为明显。由于其轮询机制和文件描述符数量限制，`select` 在现代高并发应用中逐渐被其他 I/O 多路复用技术（如 `epoll`、`kqueue`、`poll`）所取代。在现代的网络编程中，对于大规模并发连接的处理，通常建议使用 `epoll` 或 `kqueue`，这些技术提供了更高效的事件通知和处理方式

