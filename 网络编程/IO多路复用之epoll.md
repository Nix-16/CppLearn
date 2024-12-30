# IO多路复用中的epoll

## 1. 概述

epoll 全称 eventpoll，是 linux 内核实现IO多路转接/复用（IO multiplexing）的一个实现。IO多路转接的意思是在一个操作里同时监听多个输入输出源，在其中一个或多个输入输出源可用的时候返回，然后对其的进行读写操作。epoll是select和poll的升级版，相较于这两个前辈，epoll改进了工作方式，因此它更加高效。

* 对于待检测集合select和poll是基于线性方式处理的，epoll是基于红黑树来管理待检测集合的。
* select和poll每次都会线性扫描整个待检测集合，集合越大速度越慢，epoll使用的是回调机制，效率高，处理效率也不会随着检测集合的变大而下降
* **select**和poll工作过程中存在内核/用户空间数据的频繁拷贝问题，在epoll中内核和用户区使用的是共享内存（基于mmap内存映射区实现），省去了不必要的内存拷贝。
* 程序猿需要对select和poll返回的集合进行判断才能知道哪些文件描述符是就绪的，通过epoll可以直接得到已就绪的文件描述符集合，无需再次检测
* 使用epoll没有最大文件描述符的限制，仅受系统中进程能打开的最大文件数目限制

当多路复用的文件数量庞大、IO流量频繁的时候，一般不太适合使用select()和poll()，这种情况下select()和poll()表现较差，推荐使用epoll()。

## 2.操作函数

在epoll中一共提供是三个API函数，分别处理不同的操作，函数原型如下：

```c++
#include <sys/epoll.h>
// 创建epoll实例，通过一棵红黑树管理待检测集合
int epoll_create(int size);
// 管理红黑树上的文件描述符(添加、修改、删除)
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
// 检测epoll树中是否有就绪的文件描述符
int epoll_wait(int epfd, struct epoll_event * events, int maxevents, int timeout);
```

select/poll低效的原因之一是将“添加/维护待检测任务”和“阻塞进程/线程”两个步骤合二为一。每次调用select都需要这两步操作，然而大多数应用场景中，需要监视的socket个数相对固定，并不需要每次都修改。epoll将这两个操作分开，先用epoll_ctl()维护等待队列，再调用epoll_wait()阻塞进程（解耦）。

### 2.1 epoll_create()

函数的作用是创建一个红黑树模型的实例，用于管理待检测的文件描述符的集合。

```c++
int epoll_create(int size);
```

* 函数参数 size：在Linux内核2.6.8版本以后，这个参数是被忽略的，只需要指定一个大于0的数值就可以了。
* 函数返回值：
  * 失败：返回-1
  * 成功：返回一个有效的文件描述符，通过这个文件描述符就可以访问创建的epoll实例了

### 2.2epoll_ctl()

函数的作用是管理红黑树实例上的节点，可以进行添加、删除、修改操作。

```c++
// 联合体, 多个变量共用同一块内存        
typedef union epoll_data {
 	void        *ptr;
	int          fd;	// 通常情况下使用这个成员, 和epoll_ctl的第三个参数相同即可
	uint32_t     u32;
	uint64_t     u64;
} epoll_data_t;

struct epoll_event {
	uint32_t     events;      /* Epoll events */
	epoll_data_t data;        /* User data variable */
};
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
```

函数参数：

* epfd：epoll_create() 函数的返回值，通过这个参数找到epoll实例

* op：这是一个枚举值，控制通过该函数执行什么操作

  * EPOLL_CTL_ADD：往epoll模型中添加新的节点
  * EPOLL_CTL_MOD：修改epoll模型中已经存在的节点
  * EPOLL_CTL_DEL：删除epoll模型中的指定的节点

* fd：文件描述符，即要添加/修改/删除的文件描述符

* event：epoll事件，用来修饰第三个参数对应的文件描述符的，指定检测这个文件描述符的什么事件

  * events：委托epoll检测的事件

    * EPOLLIN：读事件, 接收数据, 检测读缓冲区，如果有数据该文件描述符就绪
    * EPOLLOUT：写事件, 发送数据, 检测写缓冲区，如果可写该文件描述符就绪
    * EPOLLERR：异常事件

  * data：用户数据变量，这是一个联合体类型，通常情况下使用里边的fd成员，用于存储待检测的文件描述符的值，在调用epoll_wait()函数的时候这个值会被传出。

    

* 函数返回值：

  * 失败：返回-1
  * 成功：返回0

### 2.3 epoll_wait()

函数的作用是检测创建的epoll实例中有没有就绪的文件描述符。

```c++
int epoll_wait(int epfd, struct epoll_event * events, int maxevents, int timeout);
```

函数参数：

* epfd：epoll_create() 函数的返回值, 通过这个参数找到epoll实例
* events：传出参数, 这是一个结构体数组的地址, 里边存储了已就绪的文件描述符的信息
* maxevents：修饰第二个参数, 结构体数组的容量（元素个数）
* timeout：如果检测的epoll实例中没有已就绪的文件描述符，该函数阻塞的时长, 单位ms 毫秒
  * 0：函数不阻塞，不管epoll实例中有没有就绪的文件描述符，函数被调用后都直接返回
  * 大于0：如果epoll实例中没有已就绪的文件描述符，函数阻塞对应的毫秒数再返回
  * -1：函数一直阻塞，直到epoll实例中有已就绪的文件描述符之后才解除阻塞

函数返回值：

* 成功：
  * 等于0：函数是阻塞被强制解除了, 没有检测到满足条件的文件描述符
  * 大于0：检测到的已就绪的文件描述符的总个数
  * 失败：返回-1

## 3.使用步骤

### 3.1使用 `epoll` 的步骤：

* **创建 `epoll` 实例**: 使用 `epoll_create()` 创建一个 epoll 实例，该实例的返回值是一个文件描述符。
* **注册事件**: 使用 `epoll_ctl()` 注册需要监听的文件描述符，并指定关注的事件类型（如 `EPOLLIN`、`EPOLLOUT` 等）。
* **等待事件**: 调用 `epoll_wait()` 阻塞或非阻塞地等待事件发生。当某个文件描述符有事件发生时，`epoll_wait()` 会返回已发生事件的文件描述符。

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <arpa/inet.h>
#include <sys/epoll.h>

#define MAX_EVENTS 10

int main() {
    // 1. 创建监听的socket
    int lfd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(9999);
    addr.sin_addr.s_addr = INADDR_ANY;

    bind(lfd, (struct sockaddr*)&addr, sizeof(addr));
    listen(lfd, 5);

    // 2. 创建epoll实例
    int epoll_fd = epoll_create1(0);
    if (epoll_fd == -1) {
        perror("epoll_create1 failed");
        close(lfd);
        return -1;
    }

    // 3. 注册监听的socket到epoll实例
    struct epoll_event event;
    event.events = EPOLLIN;  // 监听读事件
    event.data.fd = lfd;
    if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, lfd, &event) == -1) {
        perror("epoll_ctl failed");
        close(lfd);
        close(epoll_fd);
        return -1;
    }

    // 4. 等待事件发生
    struct epoll_event events[MAX_EVENTS];
    while (1) {
        int n = epoll_wait(epoll_fd, events, MAX_EVENTS, -1);
        if (n == -1) {
            perror("epoll_wait failed");
            break;
        }

        // 处理发生事件的文件描述符
        for (int i = 0; i < n; i++) {
            if (events[i].data.fd == lfd) {
                // 监听socket有新连接
                int cfd = accept(lfd, NULL, NULL);
                if (cfd == -1) {
                    perror("accept failed");
                    continue;
                }

                // 注册新连接到epoll实例
                event.events = EPOLLIN | EPOLLET;  // 可读事件，边缘触发模式
                event.data.fd = cfd;
                if (epoll_ctl(epoll_fd, EPOLL_CTL_ADD, cfd, &event) == -1) {
                    perror("epoll_ctl failed");
                    close(cfd);
                    continue;
                }
                printf("New client connected, cfd = %d\n", cfd);
            } else if (events[i].events & EPOLLIN) {
                // 可读事件，读取数据
                char buf[1024] = {0};
                int len = read(events[i].data.fd, buf, sizeof(buf));
                if (len == 0) {
                    // 客户端关闭了连接
                    printf("Client disconnected, fd = %d\n", events[i].data.fd);
                    close(events[i].data.fd);
                } else if (len > 0) {
                    printf("Received from client: %s\n", buf);
                    write(events[i].data.fd, buf, len);  // 回显数据
                } else {
                    perror("read error");
                }
            }
        }
    }

    close(lfd);
    close(epoll_fd);
    return 0;
}
```

### 3.2`epoll` 的优势：

* **高效性**：`epoll` 在处理大量文件描述符时，避免了每次遍历所有文件描述符的开销。它只关心那些已经发生事件的文件描述符，极大提升了性能。
* **不受文件描述符数量限制**：`epoll` 不受 `select` 的 `FD_SETSIZE` 限制，可以处理成千上万的文件描述符。
* **支持边缘触发**：`epoll` 支持 **边缘触发（EPOLLET）** 模式，这使得在事件发生时可以进行一次性通知，减少了重复的事件通知。

### 3.3总结

`epoll` 是一种更高效的 I/O 多路复用机制，特别适用于高并发的网络应用。与 `select` 和 `poll` 不同，`epoll` 使用基于事件的通知机制，避免了不必要的文件描述符轮询，显著提高了性能。`epoll` 的优势在于能够处理大量文件描述符，并且具有支持边缘触发和一次性事件通知的能力。

## 4.边沿触发和水平触发的区别

**边缘触发（Edge Triggered, ET）** 和 **水平触发（Level Triggered, LT）** 是两种常见的事件通知机制，特别是在 `epoll` 中用于文件描述符的事件触发方式。它们之间的主要区别在于事件通知的方式和事件的处理方式。

### 4.1. **水平触发（Level Triggered, LT）**

在 **水平触发模式**下，文件描述符只要处于事件状态，就会不断触发相同的事件。具体来说，当你调用 `epoll_wait()` 时，系统会检查文件描述符的状态，如果事件（如可读、可写等）仍然存在，它就会一直返回该文件描述符，直到事件处理完毕。

**特点**:

- **事件重复触发**：只要文件描述符的事件没有完全处理，`epoll_wait()` 就会重复通知你该事件。
- **适合简单场景**：对于不想错过任何事件并且事件处理较为简单的场景，使用水平触发非常合适。比如，标准的非阻塞 I/O 就是基于水平触发的。
- **多次触发**：即使应用程序还未完全处理完数据，`epoll_wait()` 可能会重复返回该文件描述符，因为文件描述符的状态仍然符合触发条件。

**示例**：

- 当你在一个 socket 上调用 `read()` 时，如果缓冲区没有完全读完数据，`epoll_wait()` 会再次返回这个文件描述符，直到数据全部读完为止。

### 4.2. **边缘触发（Edge Triggered, ET）**

在 **边缘触发模式**下，事件只会在状态变化时触发一次。当文件描述符的状态发生变化时，`epoll_wait()` 只会在该变化发生的“边缘”通知你一次。之后，如果事件的状态仍然存在，即使你没有处理完，也不会再次通知，直到状态发生变化为止。

**特点**:

- **事件仅触发一次**：只会在事件状态发生变化时触发一次。
- **需要立即处理事件**：由于事件只通知一次，如果应用程序没有及时处理，可能会错过事件，导致状态没有得到及时处理。
- **效率较高**：边缘触发模式通常能减少不必要的系统调用和事件通知，适用于高性能和高并发场景。

**示例**：

- 当你在一个 socket 上调用 `read()` 时，如果有数据可以读取，`epoll_wait()` 会通知你一次，但如果有更多的数据在缓冲区中，它不会再通知你，直到有新的数据到达。

### 4.3. **边缘触发与水平触发的比较**

| 特性             | 水平触发 (Level Triggered, LT)                   | 边缘触发 (Edge Triggered, ET)                    |
| ---------------- | ------------------------------------------------ | ------------------------------------------------ |
| **事件通知频率** | 持续通知，只要事件状态没有处理完，事件会重复触发 | 只会通知一次，直到事件状态发生变化               |
| **事件处理方式** | 可以处理多个事件，无需立即处理所有事件           | 一旦通知，必须立即处理所有事件，否则会错过       |
| **性能**         | 可能会有不必要的重复通知，性能较低               | 更高效，不会重复通知，相同事件只会触发一次       |
| **使用场景**     | 适合较为简单的场景，事件处理不复杂               | 适合高并发、性能要求较高的场景，需要快速处理事件 |
| **应用复杂度**   | 事件处理较为简单，不会错过任何事件               | 需要确保每次事件都能及时处理，复杂度较高         |

### 4.4. **如何选择**

- **水平触发（LT）** 是默认的触发模式，适合绝大多数的应用。它不容易错过事件，应用程序可以较为简单地处理数据，不用担心丢失事件。
- **边缘触发（ET）** 适用于性能要求较高的场景，特别是当文件描述符的数量非常大时。通过避免重复的事件通知，`epoll` 可以显著减少 I/O 处理的开销。不过，它要求应用程序必须足够高效地处理所有事件，否则可能会错过后续的事件。

### 4.5. **示例代码对比：水平触发与边缘触发**

假设我们有一个服务器使用 `epoll` 监听 socket 的可读事件。

#### 水平触发示例：

```c
struct epoll_event event;
event.events = EPOLLIN; // 默认就是水平触发
event.data.fd = socket_fd;
epoll_ctl(epoll_fd, EPOLL_CTL_ADD, socket_fd, &event);

while (1) {
    int n = epoll_wait(epoll_fd, events, MAX_EVENTS, -1);
    for (int i = 0; i < n; i++) {
        if (events[i].events & EPOLLIN) {
            // 处理读取数据
            char buf[1024];
            int len = read(events[i].data.fd, buf, sizeof(buf));
            if (len == 0) {
                // 客户端关闭连接
                close(events[i].data.fd);
            } else {
                // 处理数据
                write(events[i].data.fd, buf, len);  // 回显数据
            }
        }
    }
}
```

#### 边缘触发示例：

```c
struct epoll_event event;
event.events = EPOLLIN | EPOLLET;  // 使用边缘触发
event.data.fd = socket_fd;
epoll_ctl(epoll_fd, EPOLL_CTL_ADD, socket_fd, &event);

while (1) {
    int n = epoll_wait(epoll_fd, events, MAX_EVENTS, -1);
    for (int i = 0; i < n; i++) {
        if (events[i].events & EPOLLIN) {
            // 处理读取数据
            char buf[1024];
            int len = 0;
            
            // 循环读取数据，直到所有数据被读取
            while ((len = read(events[i].data.fd, buf, sizeof(buf))) > 0) {
                // 处理数据
                write(events[i].data.fd, buf, len);  // 回显数据
            }
            
            if (len == 0) {
                // 客户端关闭连接
                close(events[i].data.fd);
            } else if (len < 0) {
                // 读取错误
                perror("read error");
            }
        }
    }
}
```

### 4.6总结：

- **水平触发（LT）**：事件状态持续存在时，`epoll_wait()` 会一直返回该文件描述符，直到事件被处理完。这使得它适用于不想错过任何事件的简单场景。
- **边缘触发（ET）**：事件只会在状态发生变化时触发一次，适用于高效的事件处理场景，但要求应用程序能够及时处理所有事件，否则可能错过后续的事件。

总结来说，选择水平触发或边缘触发应根据应用场景的需要来定。如果你需要处理大量并发连接并且需要最小化事件通知次数，**边缘触发**是更好的选择。如果你需要简单易用、稳定的机制，**水平触发**可能更加适合。