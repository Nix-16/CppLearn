# I/O 多路复用中的 `poll`

`poll` 是一种 I/O 多路复用机制，与 `select` 类似，但它解决了一些 `select` 的限制问题。`poll` 是一个系统调用，用来监视多个文件描述符（如网络连接、文件等）是否可读、可写或发生异常。它通过返回一个事件列表来告诉程序哪些文件描述符的状态发生了变化。

## 1.`poll` 的特点

* **更灵活的事件描述：** 相较于 `select`，`poll` 使用一个结构体来表示每个文件描述符及其对应的事件，而不是单独的文件描述符集合。

* **没有文件描述符数量限制：** `poll` 没有 `select` 的最大文件描述符数限制。`select` 的 `fd_set` 最大值通常是 1024（或者操作系统默认的其他值），而 `poll` 只受系统内存限制。

* **事件驱动：** `poll` 通过返回触发事件的文件描述符列表，程序只需要处理发生事件的文件描述符，避免了不必要的循环检查。

## 2.函数原型

```c
int poll(struct pollfd *fds, nfds_t nfds, int timeout);

struct pollfd {
    int fd;      // 文件描述符
    short events; // 需要监听的事件
    short revents; // 发生的事件
};
```

* `fds`: 需要监控的文件描述符数组。

* `nfds`: 数组中 `pollfd` 的数量。

* `timeout`: 超时值，单位毫秒。设置为 -1 表示无限期阻塞。

**事件标志：** `poll` 使用标志来指定感兴趣的事件。常见的事件标志有：

- `POLLIN`：文件描述符可以读取（即数据可用）。
- `POLLOUT`：文件描述符可以写入（即缓冲区有空间）。
- `POLLERR`：文件描述符发生错误。
- `POLLHUP`：文件描述符被挂起。
- `POLLPRI`：文件描述符有紧急数据。

**返回值**：

* **`ret > 0`**：表示 `poll` 成功，且至少有一个文件描述符的事件发生了，程序可以遍历 `fds` 数组中的 `revents` 字段来查看哪些文件描述符发生了哪些事件。

* **`ret == 0`**：表示超时，`poll` 阻塞了指定的超时时间，但没有任何文件描述符发生事件。此时，程序可以选择重新调用 `poll` 或执行其他操作。

* **`ret < 0`**：表示发生了错误，`errno` 会提供具体的错误信息。

## 3.使用流程

* **初始化文件描述符集合：** 使用 `pollfd` 结构体来定义需要监听的文件描述符和关注的事件。每个 `pollfd` 结构体代表一个文件描述符及其状态。

* **调用 `poll`：** `poll` 会阻塞直到至少有一个文件描述符的事件发生，或者超时。

* **处理事件：** `poll` 返回后，程序遍历返回的事件列表，处理每个发生事件的文件描述符。

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <arpa/inet.h>
#include <poll.h>

#define MAX_CLIENTS 100

int main()
{
    // 创建监听的文件描述符
    int lfd = socket(AF_INET, SOCK_STREAM, 0);
    if (lfd == -1) {
        perror("socket error");
        return 1;
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(9999);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    if (bind(lfd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind error");
        close(lfd);
        return 1;
    }

    if (listen(lfd, 5) < 0) {
        perror("listen error");
        close(lfd);
        return 1;
    }

    // 设置 pollfd 数组，用于监控文件描述符
    struct pollfd fds[MAX_CLIENTS];
    fds[0].fd = lfd;
    fds[0].events = POLLIN;  // 监听是否有新的连接
    int nfds = 1;  // 当前活跃的文件描述符数量

    while (1) {
        int ret = poll(fds, nfds, -1);  // 阻塞直到事件发生
        if (ret < 0) {
            perror("poll error");
            break;
        }

        // 检查监听套接字是否有新的连接
        if (fds[0].revents & POLLIN) {
            struct sockaddr_in cliaddr;
            socklen_t clilen = sizeof(cliaddr);
            int cfd = accept(lfd, (struct sockaddr*)&cliaddr, &clilen);
            if (cfd < 0) {
                perror("accept error");
                continue;
            }

            // 将新的客户端文件描述符加入到 pollfd 数组
            fds[nfds].fd = cfd;
            fds[nfds].events = POLLIN;  // 监听该文件描述符是否可读
            nfds++;

            printf("New client connected, cfd = %d\n", cfd);
        }

        // 遍历每个已连接的客户端，检查是否有数据可读
        for (int i = 1; i < nfds; ++i) {
            if (fds[i].revents & POLLIN) {
                char buf[1024] = {0};
                int len = read(fds[i].fd, buf, sizeof(buf));
                if (len == 0) {
                    printf("Client disconnected, fd = %d\n", fds[i].fd);
                    close(fds[i].fd);
                    fds[i] = fds[nfds - 1];  // 用最后一个连接替换断开的连接
                    nfds--;
                } else if (len > 0) {
                    printf("Received from client: %s\n", buf);
                    write(fds[i].fd, buf, len);  // 回显数据
                } else {
                    perror("read error");
                }
            }
        }
    }

    close(lfd);
    return 0;
}

```

## 4.客户端代码

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <arpa/inet.h>

int main()
{
    // 1. 创建用于通信的套接字
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if(fd == -1)
    {
        perror("socket");
        exit(0);
    }

    // 2. 连接服务器
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;     // ipv4
    addr.sin_port = htons(9999);   // 服务器监听的端口, 字节序应该是网络字节序
    inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr.s_addr);
    int ret = connect(fd, (struct sockaddr*)&addr, sizeof(addr));
    if(ret == -1)
    {
        perror("connect");
        exit(0);
    }

    // 通信
    while(1)
    {
        // 读数据
        char recvBuf[1024];
        // 写数据
        // sprintf(recvBuf, "data: %d\n", i++);
        fgets(recvBuf, sizeof(recvBuf), stdin);
        write(fd, recvBuf, strlen(recvBuf)+1);
        // 如果客户端没有发送数据, 默认阻塞
        read(fd, recvBuf, sizeof(recvBuf));
        printf("recv buf: %s\n", recvBuf);
        sleep(1);
    }

    // 释放资源
    close(fd); 

    return 0;
}
```

## 5.`poll` 和 `select` 的主要区别：

### 5.1**事件驱动 vs 描述符驱动**

- `select` 是基于 **文件描述符**，它依赖于检测每个文件描述符的状态。
- `poll` 是基于 **事件**，它依赖于设置事件标志，并返回哪些事件发生。

### 5.2**事件的管理**

- `select` 使用的文件描述符集合需要每次调用前后都重新设置，因为 `select` 会修改传入的集合。
- `poll` 直接使用 `pollfd` 结构体数组，每次调用时返回各个文件描述符的事件状态。

### 5.3**文件描述符数量**

- `select` 的最大文件描述符数量受限于系统的 `FD_SETSIZE`（通常是 1024）。
- `poll` 的文件描述符数量不受固定限制，只受可用内存和系统资源的限制。

### 5.4**性能**

- 当监控的文件描述符数量较多时，`select` 可能会导致性能下降，因为它每次都要遍历整个文件描述符集合。
- `poll` 可以更高效地处理大量的文件描述符，因为它只遍历活跃的文件描述符。

### 5.5总结

`poll` 是基于 **事件** 的机制，每个文件描述符有一个事件标志来表示该描述符的状态。相比于 `select`，`poll` 更灵活，能够处理更多的文件描述符，且没有文件描述符数量的硬性限制。