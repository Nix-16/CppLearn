## Socket  `API`

### 1.`socket`简介
套接字（socket）是一种通信机制，凭借这种机制， 客户端<->服务器 模型的通信方式既可以在本地设备上进行，也可以跨网络进行。

Socket英文原意是“孔”或者“插座”的意思，在网络编程中，通常将其称之为“套接字”，当前网络中的主流程序设计都是使用Socket进行编程的，因为它简单易用，它还是一个标准（BSD Socket），能在不同平台很方便移植，比如你的一个应用程序是基于Socket编程的，那么它可以移植到任何实现BSD Socket标准的平台，比如`LwIP`，它兼容BSD Socket；又比如Windows，它也实现了一套基于Socket的套接字接口，更甚至在国产操作系统中，如RT-Thread，它也实现了BSD Socket标准的Socket接口。

在Socket中，它使用一个套接字来记录网络的一个连接，套接字是一个整数，就像我们操作文件一样，利用一个文件描述符，可以对它打开、读、写、关闭等操作，类似的，在网络中，我们也可以对Socket套接字进行这样子的操作，比如开启一个网络的连接、读取连接主机发送来的数据、向连接的主机发送数据、终止连接等操作。

我们来了解一下套接字描述符，它跟我们的文件描述符非常像，其实就是一个整数，套接字`API`最初是作为UNIX操作系统的一部分而开发的，所以套接字`API`与系统的其他I/O设备集成在一起。当应用程序要为网络通信而创建一个套接字（socket）时，操作系统就返回一个整数作为描述符（descriptor）来标识这个套接字。然后，应用程序以该描述符作为传递参数，通过调用Socket API接口的函数来完成某种操作（例如通过网络传送数据或接收输入的数据）。

接下来讲解Linux系统中的套接字相关的函数，但注意要包含网络编程中常用的头文件：
```
#include <sys/types.h>
#include <sys/socket.h>
```

### 2.`socket()`
函数原型
```
int socket(int domain, int type, int protocol);
```
socket()函数用于创建一个socket描述符（socket descriptor），它唯一标识一个socket，这个socket描述符跟文件描述符一样，后续的操作都有用到它，把它作为参数，通过它来进行一些读写操作。

#### 2.1 参数详解

创建socket的时候，也可以指定不同的参数创建不同的socket描述符，socket函数的三个参数分别为：

1. domain 地址族（协议族）：

* 参数domain表示该套接字使用的地址族（协议族），常见的选项包括：
  * `AF_INET`：IPv4 网络协议，使用 IP 地址进行通信。
  * ` AF_INET6 `：IPv6 网络协议。
  * `AF_UNIX`：本地通信（同一台机器上的进程间通信）。

* 在网络编程中，最常用的是 `AF_INET`，用于建立基于 IPv4 的网络连接。

2. type：套接字类型，常见的类型有以下几种：

* SOCK_STREAM：流式套接字，使用 `TCP` 协议，提供可靠的字节流服务。
* SOCK_DGRAM：数据报套接字，使用 `UDP` 协议，不保证数据可靠性。
* SOCK_RAW：原始套接字，允许直接访问 `IP` 层，常用于底层网络开发，如自定义协议。

3. protocol：协议，通常可以设置为 0，由系统自动选择适当的协议。
   * 常见协议值：
     * `IPPROTO_TCP`：TCP 协议（通常与 `SOCK_STREAM` 配合使用）。
     * `IPPROTO_UDP`：UDP 协议（通常与 `SOCK_DGRAM` 配合使用）。

#### 2.2 返回值

* 成功时，返回一个非负整数，表示套接字描述符（socket descriptor）。
* 失败时，返回 `-1`，并设置 `errno` 以指示错误类型。例如，可能的错误包括：
  * `EACCES`：没有权限创建套接字。
  * `EAFNOSUPPORT`：系统不支持指定的地址族。
  * `EINVAL`：指定的协议无效。
  * `EMFILE`：进程的文件描述符已达到上限。

#### 2.3 示例代码

```c++
    int sockfd;

    // 创建一个 IPv4 地址族、流式套接字（TCP）的套接字
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd == -1) {
        perror("socket creation failed");
        exit(EXIT_FAILURE);
    }
```



### 3. bind()
函数原型
```c++
int bind(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
```
在套接口中，一个套接字只是用户程序与内核交互信息的枢纽，它自身没有太多的信息，也没有网络协议地址和端口号等信息，在进行网络通信的时候，必须把一个套接字与一个IP地址或端口号相关联，这个过程就是绑定的过程。

`bind()` 函数将一个本地地址（IP 地址和端口号）分配给套接字，用于监听特定端口。特别是对于服务器端程序，`bind` 是必不可少的一步。

#### 3.1参数详解：

* `sockfd`：套接字描述符，由 `socket()` 函数返回，用于标识所创建的套接字。
* **addr**：指向 `sockaddr` 结构体的指针，包含了要绑定的地址信息。
* `addr` 结构体的大小（使用 `sizeof(struct sockaddr_in)`）。


sockaddr 结构体内容如下：

```c++
struct sockaddr {
    sa_family_t     sa_family;
    char            sa_data[14];
};
```

咋一看这个结构体，好像没啥信息要我们填写的，确实也是这样子，我们需要填写的IP地址与端口号等信息，都在sa_data连续的14字节信息里面，但这个结构体对用户操作不友好，一般我们在使用的时候都会使用sockaddr_in结构体，sockaddr_in和sockaddr是并列的结构（占用的空间是一样的），指向sockaddr_in的结构体的指针也可以指向sockadd的结构体，并代替它，而且sockaddr_in结构体对用户将更加友好，在使用的时候进行类型转换就可以了。
sockaddr_in结构体：

```c++
struct sockaddr_in {
    short int sin_family;               /* 协议族 */
    unsigned short int sin_port;        /* 端口号 */
    struct in_addr sin_addr;            /* IP地址 */
    unsigned char sin_zero[8];          /* sin_zero是为了让sockaddr与sockaddr_in两个数据结构体保持大小相同而保留的空字节 */
};
```
sockaddr_in结构体的第一个字段是与sockaddr结构体是一致的，而剩下的字段就是sa_data连续的14字节信息里面的内容，只不过重新定义了成员变量而已，sin_port字段是我们需要填写的端口号信息，sin_addr字段是我们需要填写的IP地址信息，剩下sin_zero 区域的8字节保留未用。

* `sin_family`：应与 `socket` 函数中的 `domain` 参数一致（通常为 `AF_INET`）。
* `sin_port`：端口号，通过 `htons()` 转换为网络字节序。
* `sin_addr`：IP 地址，可以使用 `INADDR_ANY` 绑定到所有本地 IP。

#### 3.2返回值

* 成功时返回 `0`。

* 失败时返回 `-1`，并设置 `errno` 以指示错误类型，常见错误：
  * `EADDRINUSE`：指定的地址已在使用，通常是端口号被占用。
  * `EADDRNOTAVAIL`：指定的地址不可用，可能因为地址无效或未配置在本地。
  * `EBADF`：套接字描述符无效，可能是未成功调用 `socket()`。

#### 3.3 示例代码

```c++
    struct sockaddr_in server_addr;
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(8080);       // 绑定端口 8080
    server_addr.sin_addr.s_addr = INADDR_ANY; // 绑定到所有可用地址

    if (bind(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr)) == -1) {
        perror("Bind failed");
        close(sockfd);
        exit(EXIT_FAILURE);
    }
```



### 4. connect()

函数原型
```C++
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen);
```

`connect()` 函数用于将客户端套接字连接到服务器指定的地址和端口，以建立与远程主机的连接。它是客户端发起网络连接的关键步骤。在TCP客户端中调用这个函数将发生握手过程（会发送一个TCP连接请求），并最终建立一个TCP连接，而对于 `UDP `协议来说，调用这个函数只是在` sockfd `中记录远端` IP `地址与端口号，而不发送任何数据，参数信息与bind()函数是一样的。

函数调用成功则返回0，失败返回-1，错误原因存于 `errno` 中。

connect()函数是套接字连接操作，对于TCP协议来说，connect()函数操作成功之后代表对应的套接字已与远端主机建立了连接，可以发送与接收数据。

对于UDP协议来说，没有连接的概念，在这里可将其描述为记录远端主机的`IP`地址与端口号，`UDP`协议经过connect()函数调用成功之后，在通过sendto()函数发送数据报时不需要指定目的地址、端口，因为此时已经记录到了远端主机的IP地址与端口号。`UDP`协议还可以给同一个套接字进行多次connect()操作，而TCP协议不可以，TCP只能指定一次connect操作。

### 5. listen()
listen()函数只能在TCP服务器进程中使用，让服务器进程进入监听状态，等待客户端的连接请求，listen()函数在一般在bind()函数之后调用，在accept()函数之前调用，它的函数原型是：
```c++
int listen(int sockfd, int backlog);
```
参数：
* `sockfd`：`sockfd`是由socket()函数返回的套接字描述符。

* `backlog` 是用来描述 `sockfd` 的等待连接队列可以达到的最大值。在服务器进程处理客户端连接请求的过程中，可能有多个客户端同时尝试连接。由于TCP连接的建立需要时间，服务器进程无法立即处理所有请求，因此内核会维护一个有限大小的等待队列，将这些连接请求按顺序放入其中，供服务器依次处理。

  然而，这个队列的大小不可能无限大，必须设定一个上限，`backlog` 参数即为内核提供了这个上限的值。当新的连接请求到达而等待队列已满时，该请求将被丢弃，客户端可能会收到一个连接失败的错误提示。

返回值

成功时返回 `0`。

失败时返回 `-1`，并设置 `errno` 来指示错误类型。


### 6. accept()
函数原型：
```c++
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
```
为了能够正常让TCP客户端能正常连接到服务器，服务器必须遵循以下流程处理：
1) 调用socket()函数创建对应的套接字类型。
2) 调用bind()函数将套接字绑定到本地的一个端口地址。
3) 调用listen()函数让服务器进程进入监听状态，等待客户端的连接请求。
4) 调用accept()函数处理到来的连接请求。

accept()函数用于TCP服务器中，等待着远端主机的连接请求，并且建立一个新的TCP连接，在调用这个函数之前需要通过调用listen()函数让服务器进入监听状态，如果队列中没有未完成连接套接字，并且套接字没有标记为非阻塞模式，accept()函数的调用会阻塞应用程序直至与远程主机建立TCP连接；如果一个套接字被标记为非阻塞式而队列中没有未完成连接套接字, 调用accept()函数将立即返回`EAGAIN`。

所以，accept()函数就是用于处理连接请求的，它会从未完成连接队列中取出第一个连接请求，建一个和参数 `sockfd `属性相同的连接套接字，并为这个套接字分配一个文件描述符, 然后以这个描述符返回，新创建的描述符不再处于监听状态，原套接字 s 不受此调用的影响，还是会处于监听状态，因为 s 是由socket()函数创建的，而处理连接时accept()函数会创建另一个套接字。	

参数addr用来返回已连接的客户端的IP地址与端口号，参数addrlen用于返回addr所指向的地址结构体的字节长度，如果我们对客户端的IP地址与端口号不感兴趣，可以把arrd和addrlen均置为空指针。

若连接成功则返回一个socket描述符（非负值），若出错则为-1。

如果accept()连接成功，那么其返回值是由内核自动生成的一个全新描述符，代表与客户端的TCP连接，一个服务器通常仅仅创建一个监听套接字，它在该服务器生命周期内一直存在，内核为每个由服务器进程接受的客户端连接创建一个已连接套接字。

### 7. read()
一旦客户端与服务器建立好TCP连接之后，我们就可以通过`sockfd`套接字描述符来收发数据，这与我们读写文件是差不多的操作，接收网络中的数据函数可以是read()、`recv()`、`recvfrom()`等。

函数原型：
```c++
ssize_t read(int fd, void *buf, size_t count);
ssize_t recv(int sockfd, void *buf, size_t len, int flags);
ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags,  struct sockaddr *src_addr, socklen_t *addrlen);
ps：ssize_t 它表示的是 signed size_t 类型。

read() 从描述符 fd （描述符可以是文件描述符也可以是套接字描述符，本章主要讲解套接字，此处fd为套接字描述符）中读取 count 字节的数据并放入从 buf 开始的缓冲区中，read()函数调用成功返回读取到的字节数，此返回值受文件剩余字节数限制，当返回值小于指定的字节数时 并不意味着错误；这可能是因为当前可读取的字节数小于指定的 字节数（比如已经接近文件结尾，或者正在从管道或者终端读取数据，或者read()函数被信号中断等），出错返回-1并设置errno，如果在调read之前已到达文件末尾，则这次read返回0。
```
参数：
* fd：在socket编程中是指定套接字描述符。
* buf：指定存放数据的地址。
* count：是指定读取的字节数，将读取到的数据保存在缓冲区buf中。

错误代码：
* EINTR：在读取到数据前被信号所中断。
* EAGAIN：使用O_NONBLOCK 标志指定了非阻塞式输入输出，但当前没有数据可读。
* EIO：输入输出错误，可能是正处于后台进程组进程试图读取其控制终端，但读操作无效，或者被信号SIGTTIN所阻塞, 或者其进程组是孤儿进程组，也可能执行的是读磁盘或者磁带机这样的底层输入输出错误。
* EISDIR：fd 指向一个目录。
* EBADF：fd不是一个合法的套接字描述符，或者不是为读操作而打开。
* EINVAL：fd所连接的对象不可读。
* EFAULT：buf 超出用户可访问的地址空间。

### 8. `recv()`
函数原型：
```
ssize_t recv(int sockfd, void *buf, size_t len, int flags);
```

不论是客户端还是服务器应用程序都可以用recv()函数从TCP连接的另一端接收数据，它与read()函数的功能是差不多的。

recv()函数会先检查套接字 s 的接收缓冲区，如果 s 接收缓冲区中没有数据或者协议正在接收数据，那么recv就一直等待，直到协议把数据接收完毕。当协议把数据接收完毕，recv()函数就把 s 的接收缓冲中的数据拷贝到 buf 中，但是要注意的是议接收到的数据可能大于buf的长度，所以在这种情况下要调用几次recv()函数才能把s的接收缓冲中的数据拷贝完。recv()函数仅仅是拷贝数据，真正的接收数据是由协议来完成的，recv函数返回其实际拷贝的字节数。如果recv()函数在拷贝时出错，那么它返回SOCKET_ERROR；如果recv()函数在等待协议接收数据时网络中断了，那么它返回0。

参数：
* sockfd：指定接收端套接字描述符。
* buf：指定一个接收数据的缓冲区，该缓冲区用来存放recv()函数接收到的数据。
* len：指定recv()函数拷贝的数据长度。

参数 flags 一般设置为0即可，其他数值定义如下:
* MSG_OOB：接收以out-of-band送出的数据。
* MSG_PEEK：保持原有数据，就是说接收到的数据并不会被删除,如果再调用recv()函数还会拷贝相同的数据到buf中。
* MSG_WAITALL：强迫接收到指定len大小的数据后才能返回,除非有错误或信号产生。
* MSG_NOSIGNAL：recv()函数不会被SIGPIPE信号中断，返回值成功则返回接收到的字符数,失败返回-1，错误原因存于errno中。

错误代码：
* EBADF：fd 不是一个合法的套接字描述符，或者不是为读操作而打开。
* EFAULT：buf 超出用户可访问的地址空间。
* ENOTSOCK：参数 s 为一文件描述词, 非socket.
* EINTR：在读取到数据前被信号所中断。
* EAGAIN：此动作会令进程阻塞, 但参数s的 socket 为不可阻塞。
* ENOBUFS：buf内存空间不足
* ENOMEM：内存不足。
* EINVAL：传入的参数不正确。

### 9. `write()`
函数原型：
```
ssize_t write(int fd, const void *buf, size_t count);
```
write()函数一般用于处于稳定的TCP连接中传输数据，当然也能用于UDP协议中，它向套接字描述符 fd 中写入 count 字节的数据，数据起始地址由 buf 指定，函数调用成功返回写的字节数，失败返回-1，并设置errno变量。

在网络编程中，当我们向套接字描述符写数据时有两种可能：

1. write()函数的返回值大于0，表示写了部分数据或者是全部的数据，这样我们可以使用一个while循环不断的写入数据，但是循环过程中的 buf 参数和 count 参数是我们自己来更新的，也就是说，网络编程中写函数是不负责将全部数据写完之后再返回的，说不定中途就返回了！

2. 返回值小于0，此时出错了，需要根据错误类型进行相应的处理。

所以一般我们处理写数据的时候都会自己封装一层，以保证数据的正确写入：
```
/* Write "n" bytes to a descriptor. */
ssize_t writen(int fd, const void *vptr, size_t n)
{
    size_t      nleft;      //剩余要写的字节数
    ssize_t     nwritten;   //已经写的字节数
    const char  *ptr;       //write的缓冲区

    ptr = vptr;             //把传参进来的write要写的缓冲区备份一份
    nleft = n;              //还剩余需要写的字节数初始化为总共需要写的字节数

    //检查传参进来的需要写的字节数的有效性
    while (nleft > 0) {
        if ( (nwritten = write(fd, ptr, nleft)) <= 0) { //把ptr写入fd
            if (nwritten < 0 && errno == EINTR) //当write返回值小于0且因为是被信号打断
                nwritten = 0;       /* and call write() again */
            else
                return(-1);         /* error 其他小于0的情况为错误*/
        }

        nleft -= nwritten;          //还剩余需要写的字节数=现在还剩余需要写的字节数-这次已经写的字节数
        ptr += nwritten;          //下次开始写的缓冲区位置=缓冲区现在的位置右移已经写了的字节数大小
    }
    return(n); //返回已经写了的字节数
}
```
### 10. send()
函数原型：
```
int send(int s, const void *msg, size_t len, int flags);
```
无论是客户端还是服务器应用程序都可以用send()函数来向TCP连接的另一端发送数据。

参数：
* s：指定发送端套接字描述符。
* msg：指定要发送数据的缓冲区。
* len：指明实际要发送的数据的字节数。
* flags：一般设置为0即可

当调用该函数时，send()函数会先比较待发送数据的长度len和套接字s的发送缓冲的长度。 如果len大于s的发送缓冲区的长度，该函数返回SOCKET_ERROR； 如果len小于或者等于s的发送缓冲区的长度，那么send()函数先检查协议是否 正在发送s的发送缓冲中的数据，如果是就等待协议把数据发送完，如果协议还没有开始发送s 的发送缓冲中的数据或者s的发送缓冲中没有数据，那么send()函数就比较s的发送缓冲区的 剩余空间和len。如果len大于剩余空间大小，send()函数就一直等待协议 把s的发送缓冲中的数据发送完。如果len小于剩余空间大小，send()函数就仅仅把buf中的数据 拷贝到s的发送缓冲区的剩余空间里。

如果send()函数拷贝数据成功，就返回实际copy的字节数，如果send()函数在拷贝数据时出现错误，那么send就返回SOCKET_ERROR；如果send在等待协议传送数据时网络断开的话，那么send函数也返回SOCKET_ERROR。

send()函数把buf中的数据成功拷贝到s的发送缓冲的剩余空间里后它就返回了，但是此时这些数据并不一定马上被传到连接的另一端。

### 11. `sendto()`
函数原型:
```
int sendto(int s, const void *msg, size_t len, int flags, const struct sockaddr *to, socklen_t tolen);
```
sendto()函数与send函数非常像，但是它会通过 struct sockaddr 指向的 to 结构体指定要发送给哪个远端主机，在to参数中需要指定远端主机的IP地址、端口号等，而tolen参数则是指定to 结构体的字节长度。

### 12. close()
函数原型：
```
int close(int fd);
```
close()函数是用于关闭一个指定的套接字，在关闭套接字后，将无法使用对应的套接字描述符，这个函数比较简单，当你不需要使用某个套接字描述符时，就将其关闭即可，在`UDP`协议中，close会释放一个套接字描述符的资源；而在TCP协议中，当调用close()函数后将发起“四次挥手”终止连接，当连接正式终止后，套接字描述符的资源才会被释放。

### 13.` ioctlsocket()`
函数原型：
```
int ioctlsocket( int s, long cmd, u_long *argp);
```
该函数用于获取与设置套接字相关的操作参数。

参数：
1. s：指定要操作的套接字描述符。
2. cmd：对套接字s的操作命令。
* FIONBIO：命令用于允许或禁止套接字的非阻塞模式。在这个命令下， argp参数指向一个无符号长整型，如果该值为0则表示禁止非阻塞模式， 而如果该值非0则表示允许非阻塞模式。当创建一个套接字的时候，它就处于阻塞模式， 也就是说非阻塞模式被禁止，这种情况下所有的发送、接收函数都会是阻塞的， 直至发送、接收成功才得以继续运行；而如果是非阻塞模式下，所有的发送、接收函数都是不阻塞的， 如果发送不出去或者接收不到数据，将直接返回错误代码给用户， 这就需要用户对这些“意外”情况进行处理，保证代码的健壮性。
* FIONREAD：FIONREAD命令确定套接字s自动读入的数据量，这些数据已经被接收， 但应用线程并未读取的，所以可以使用这个函数来获取这些数据的长度，在这个命令状态下， argp参数指向一个无符号长整型，用于保存函数的返回值（即未读数据的长度）。 如果套接字是SOCK_STREAM类型，则FIONREAD命令会返回recv()函数中所接收的所有数 据量，这通常与在套接字接收缓存队列中排队的数据总量相同；而如果套接字是 SOCK_DGRAM类型的，则FIONREAD命令将返回在套接字接收缓存队列中排队的 第一个数据包大小。
* SIOCATMARK：确认是否所有的带外数据都已被读入。
3. argp：指向cmd命令所带参数的指针。

其实这个函数，举个例子：
```  
// 控制为阻塞模式。
u_long mode = 0;
ioctlsocket(s,FIONBIO,&mode);

// 控制为非阻塞模式。
u_long mode = 1;
ioctlsocket(s,FIONBIO,&mode);
```

### 14. getsockopt()、setsockopt()
```
int getsockopt(int sockfd, int level, int optname,
                void *optval, socklen_t *optlen);

int setsockopt(int sockfd, int level, int optname,
                const void *optval, socklen_t optlen);
```
看名字就知道，这个函数是用于获取/设置套接字的一些选项的，参数level有多个常见的选项，如：
* SOL_SOCKET：表示在Socket层。
* IPPROTO_TCP：表示在TCP层。
* IPPROTO_IP： 表示在IP层。

参数optname表示该层的具体选项名称，比如：
* 对于SOL_SOCKET选项，可以是SO_REUSEADDR（允许重用本地地址和端口）、SO_SNDTIMEO（设置发送数据超时时间）、SO_SNDTIMEO（设置接收数据超时时间）、SO_RCVBUF（设置发送数据缓冲区大小）等等。
* 对于IPPROTO_TCP选项，可以是TCP_NODELAY（不使用Nagle算法）、TCP_KEEPALIVE（设置TCP保活时间）等等。
* 对于IPPROTO_IP选项，可以是IP_TTL（设置生存时间）、IP_TOS（设置服务类型）等等。
  


### 15.特点
套接字通信函数通常是阻塞的，这意味着在执行某些操作时，如果条件不满足（如没有数据可读或没有连接可接受），这些函数会阻塞程序的执行，直到条件满足为止。以下是一些常见的套接字函数及其阻塞行为：
阻塞的套接字函数

1. accept()：
* 阻塞直到有新的连接请求到达。
2. recv() 或 read()：
* 阻塞直到有数据可读。如果没有数据可读，函数将一直等待。
3. send() 或 write()：
* 在发送缓冲区已满时可能阻塞，直到数据被成功发送。
4. connect()：
* 对于 TCP 套接字，可能会阻塞直到连接成功或发生错误。

#### 15.1阻塞

在阻塞下，如果要实现并发，可以采用多线程来处理，即在服务端发送和接收数据都在子线程中处理，每有一个客户端连接，就创建一个子线程去处理通信。

**主线程**：

- 启动服务并监听端口，等待客户端连接。
- 当接收到一个新的客户端连接时，创建一个新的 **子线程** 来处理该连接。
- 主线程继续回到 `accept()` 阻塞，等待下一个客户端连接。

**子线程**：

- 每个子线程都会从主线程接受到一个客户端的连接。
- 子线程会处理客户端的请求，进行数据的接收和发送。
- 每个子线程的通信是独立的，互不干扰。

```c++
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>

#define PORT 8080
#define BUFFER_SIZE 1024

// 客户端处理函数
void *handle_client(void *client_sock_ptr) {
    int client_sock = *(int *)client_sock_ptr;
    char buffer[BUFFER_SIZE];
    ssize_t bytes_received;

    while (1) {
        memset(buffer, 0, sizeof(buffer));
        bytes_received = recv(client_sock, buffer, sizeof(buffer), 0);
        if (bytes_received <= 0) {
            // 如果收到的数据小于等于0，表示客户端断开连接或发生错误
            perror("recv failed or client disconnected");
            break;
        }
        printf("Received message: %s\n", buffer);
        send(client_sock, "Message received", 17, 0);  // 发送响应
    }

    close(client_sock);  // 关闭客户端连接
    return NULL;
}

int main() {
    int server_sock, client_sock;
    struct sockaddr_in server_addr, client_addr;
    socklen_t client_addr_len = sizeof(client_addr);
    pthread_t thread_id;

    // 创建套接字
    server_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (server_sock < 0) {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }

    // 初始化服务器地址
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(PORT);

    // 绑定套接字
    if (bind(server_sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        perror("Bind failed");
        close(server_sock);
        exit(EXIT_FAILURE);
    }

    // 开始监听
    if (listen(server_sock, 5) < 0) {
        perror("Listen failed");
        close(server_sock);
        exit(EXIT_FAILURE);
    }

    printf("Server is listening on port %d...\n", PORT);

    // 主循环：接受客户端连接
    while (1) {
        client_sock = accept(server_sock, (struct sockaddr *)&client_addr, &client_addr_len);
        if (client_sock < 0) {
            perror("Accept failed");
            continue;  // 如果 accept 失败，继续等待下一个连接
        }

        printf("New client connected\n");

        // 创建新的线程来处理客户端
        if (pthread_create(&thread_id, NULL, handle_client, (void *)&client_sock) != 0) {
            perror("Thread creation failed");
            close(client_sock);  // 失败时也要关闭客户端套接字
        } else {
            pthread_detach(thread_id);  // 分离线程，避免内存泄漏
        }
    }

    close(server_sock);  // 关闭服务器套接字
    return 0;
}
```



#### 15.2非阻塞模式
如果希望套接字通信不阻塞，可以将套接字设置为非阻塞模式。通过 fcntl() 函数，可以将套接字描述符设置为非阻塞：

```
#include <fcntl.h>

// 设置套接字为非阻塞
int flags = fcntl(sockfd, F_GETFL, 0);
fcntl(sockfd, F_SETFL, flags | O_NONBLOCK);
```

在非阻塞模式下，调用这些函数时，如果条件不满足，将立即返回，而不是阻塞。可以通过检查返回值来确定操作是否成功，通常结合 errno 来处理。

选择和轮询
非阻塞套接字通常与 select()、poll() 或 epoll() 等 I/O 多路复用技术结合使用，以便在多个套接字之间监视活动。

