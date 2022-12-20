---
layout:     post
title:      "Android P lmkd简析"
summary:    '"low memory killer"'
date:       2019-04-08 17:44:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-04-11.jpg"
catalog: true
tags:
    - android
    - memory
---


<!-- vim-markdown-toc GFM -->

* [1. 概述](#1-概述)
	* [1.1 配置用户空间lmkd](#11-配置用户空间lmkd)
* [2. lmkd进程](#2-lmkd进程)
	* [2.1 lmkd的启动](#21-lmkd的启动)
	* [2.2 lmkd的main方法](#22-lmkd的main方法)
		* [2.2.1.lmkd属性](#221lmkd属性)
		* [2.2.2 mlockall](#222-mlockall)
		* [2.2.3 `sched_setscheduler`](#223-sched_setscheduler)
		* [2.2.4 init()](#224-init)
		* [2.2.5 mainloop()](#225-mainloop)
	* [2.3 lmkd处理传递信息](#23-lmkd处理传递信息)
		* [2.3.1 `LMK_TARGET`](#231-lmk_target)
		* [2.3.2 `cmd_procprio`](#232-cmd_procprio)
		* [2.3.3 `cmd_procremove`](#233-cmd_procremove)
		* [2.3.4 小结](#234-小结)
	* [2.4 lmkd杀进程流程](#24-lmkd杀进程流程)
	* [2.5 kernel lowmemorykiller](#25-kernel-lowmemorykiller)
		* [2.5.1 kernel lowmemorykiller初始化](#251-kernel-lowmemorykiller初始化)
		* [2.5.2 kernel `lowmem_shrinker`](#252-kernel-lowmem_shrinker)
* [3 小结](#3-小结)

<!-- vim-markdown-toc -->

# 1. 概述

当系统的内存使用紧张时，底层内核会有自己的内存监控机制OOM killer，按照优先级的排列，逐步回收内存．在此基础上,Android也有类似的机制如low memory killer(后续简称为lmkd)进行内存回收．本文就是基于此目的，去分析lmkd的工作流程．首先给出大致的学习框架图:


![](/img/bill/in-posts/2019-04-10/lmkd.png)

[大图链接](http://www.cjcbill.com/img/bill/in-posts/2019-04-10/lmkd.png)

如官网叙述，过去Android利用内核中的lowmemorykiller驱动来终止进程，而从4.12开始，驱动已经不包括lowmemorykiller.c了，而是将以往的工作交到用户空间去完成:

![](/img/bill/in-posts/2019-04-10/kernel4.12.png)

与内核空间的lowmemorykiller相比，用户空间实现的lmkd可以实现同样的功能，并且利用现有的内核机制检测和估测内存压力．lmkd通过内核生成的vmpresssure事件获取内存压力级别通知，还可以使用内存cgroup功能限制分配给相应进程的内存资源．

## 1.1 配置用户空间lmkd

用户空间lmkd要求内核支持内存cgroup,因此需要更改时，需要使用以下配置编译内核:

```
CONFIG_ANDROID_LOW_MEMORY_KILLER=n
CONFIG_MEMCG=y
CONFIG_MEMCG_SWAP=y
```

# 2. lmkd进程

## 2.1 lmkd的启动

```
# lmkd.rc
service lmkd /system/bin/lmkd
    class core
    group root readproc
    critical
    socket lmkd seqpacket 0660 system system
    writepid /dev/cpuset/system-background/tasks
```

1.lmkd属于core类型服务，在on boot阶段开始运行,自O以来，启动阶段分为:

![](/img/bill/in-posts/2019-04-10/initFlow.png)

```
on boot
...
    class_start core
```

2.lmkd设置成critical，表明当崩溃超过4次时，将会重启至recovery模式:

```c++
//system/core/init/service.cpp
void Service::Reap(const siginfo_t& siginfo) {
...
if ((flags_ & SVC_CRITICAL) && !(flags_ & SVC_RESTART)) {
        if (now < time_crashed_ + 4min) {
            if (++crash_count_ > 4) {
                LOG(FATAL) << "critical process '" << name_ << "' exited 4 times in 4 minutes";
            }
        } else {
            time_crashed_ = now;
            crash_count_ = 1;
        }
    }
}
}
```

3.除此，lmkd在启动时，创建了名为lmkd的socket,这里是为了让AMS可以通过socket和lmkd进行通信，在系统启动后，可以通过查看/dev/socket目录下是否存在lmkd节点．

## 2.2 lmkd的main方法

```c
int main(int argc __unused, char **argv __unused) {
    struct sched_param param = {
            .sched_priority = 1,
    };

    /* By default disable low level vmpressure events */
    level_oomadj[VMPRESS_LEVEL_LOW] =
        property_get_int32("ro.lmk.low", OOM_SCORE_ADJ_MAX + 1);
    level_oomadj[VMPRESS_LEVEL_MEDIUM] =
        property_get_int32("ro.lmk.medium", 800);
    level_oomadj[VMPRESS_LEVEL_CRITICAL] =
        property_get_int32("ro.lmk.critical", 0);
    debug_process_killing = property_get_bool("ro.lmk.debug", false);

    /* By default disable upgrade/downgrade logic */
    enable_pressure_upgrade =
        property_get_bool("ro.lmk.critical_upgrade", false);
    upgrade_pressure =
        (int64_t)property_get_int32("ro.lmk.upgrade_pressure", 100);
    downgrade_pressure =
        (int64_t)property_get_int32("ro.lmk.downgrade_pressure", 100);
    kill_heaviest_task =
        property_get_bool("ro.lmk.kill_heaviest_task", false);
    low_ram_device = property_get_bool("ro.config.low_ram", false);
    kill_timeout_ms =
        (unsigned long)property_get_int32("ro.lmk.kill_timeout_ms", 0);
    use_minfree_levels =
        property_get_bool("ro.lmk.use_minfree_levels", false);
...
    //将该进程当前使用的以及未来使用的内存都锁住在物理内存中，放置内存被交换
    if (mlockall(MCL_CURRENT | MCL_FUTURE | MCL_ONFAULT) && errno != EINVAL)
        ALOGW("mlockall failed: errno=%d", errno);
    //设置调度策略
    sched_setscheduler(0, SCHED_FIFO, &param);
    if (!init())
        mainloop();
...
    ALOGI("exiting");
    return 0;
```

### 2.2.1.lmkd属性

第一步获取lmkd的属性，包括如下：

|属性|使用情况|默认值|
|--|--|---|
|ro.config.low_ram	|在内存不足的设备和高性能设备之间进行选择。|false|
|ro.lmk.use_minfree_levels|使用可用内存和文件缓存阈值来决定何时终止。此模式与内核 lowmemorykiller 驱动程序之前的工作原理相同|false|
|ro.lmk.low|可在低 vmpressure 级别下被终止的进程的最低 `oom_adj` 得分。	1001|（已停用）|
|ro.lmk.medium|可在中等 vmpressure 级别下被终止的进程的最低 oom_adj 得分。	800|（已缓存或非必需服务）|
|ro.lmk.critical|可在临界 vmpressure 级别下被终止的进程的最低 oom_adj 得分。	0|（任何进程）|
|ro.lmk.critical_upgrade|能够升级到临界级别。|false|
|ro.lmk.upgrade_pressure|由于系统交换次数过多，将在该级别升级 vmpressure 事件的 mem_pressure 上限。	100|（已停用）|
|ro.lmk.downgrade_pressure|由于仍有足够的可用内存，将在该级别忽略 vmpressure 事件的 mem_pressure* 下限。100|（已停用）|
|ro.lmk.kill_heaviest_task|终止符合条件的最重要任务（最佳决策）与任何符合条件的任务（快速决策）。|true|
|ro.lmk.kill_timeout_ms|从某次终止后到其他终止完成之前的持续时间（以毫秒为单位）。	0|（已停用）|
|ro.lmk.debug|启用 lmkd 调试日志。|false|


### 2.2.2 mlockall

mlocakall的作用是允许程序在物理内存上锁住全部地址空间，阻止Linux将该内存页调度到交换空间(swap space).
其中`MCL_CURRENT`为当前地址空间，`MCL_FUTURE`为锁住未来映射到到该地址的空间．
```c
if (mlockall(MCL_CURRENT | MCL_FUTURE | MCL_ONFAULT) && errno != EINVAL)
        ALOGW("mlockall failed: errno=%d", errno);
```

### 2.2.3 `sched_setscheduler`

设置当前进程调度策略为`SCHED_FIFO`，即先进先出
```c
sched_setscheduler(0, SCHED_FIFO, &param);
```

### 2.2.4 init()

lmkd作为服务端，在调用init时初始化了epoll,监听lmkd的socket套接字,并将handler设置为`ctrl_connect_handler`．当连接后，将回调handler进行处理．紧接着init还会检查路径`INKERNEL_MINFREE_PATH`("/sys/module/lowmemorykiller/parameters/minfree")是否有写权限，如果有,将在内核空间进行处理,最后完成了双向链表的初始化.

值得注意的是，当内核配置成`CONFIG_ANDROID_LOW_MEMORY_KILLER=n`时，minfree节点就不会生成，`has_inkernel_module`就默认为false.

```
static int init(void) {
    struct epoll_event epev;
    int i;
    int ret;

    page_k = sysconf(_SC_PAGESIZE);
    if (page_k == -1)
        page_k = PAGE_SIZE;
    page_k /= 1024;
    //创建epoll节点
    epollfd = epoll_create(MAX_EPOLL_EVENTS);
    if (epollfd == -1) {
        ALOGE("epoll_create failed (errno=%d)", errno);
        return -1;
    }
    //初始化时，data_socket的sock均为-1，表示未连接
    for (int i = 0; i < MAX_DATA_CONN; i++) {
        data_sock[i].sock = -1;
    }
    //获取lmkd的socket套接口fd
    ctrl_sock.sock = android_get_control_socket("lmkd");
    if (ctrl_sock.sock < 0) {
        ALOGE("get lmkd control socket failed");
        return -1;
    }
    //监听是否有客户端连接lmkd
    ret = listen(ctrl_sock.sock, MAX_DATA_CONN);
    if (ret < 0) {
        ALOGE("lmkd control socket listen failed (errno=%d)", errno);
        return -1;
    }
    //
    epev.events = EPOLLIN;
    ctrl_sock.handler_info.handler = ctrl_connect_handler;
    epev.data.ptr = (void *)&(ctrl_sock.handler_info);
    if (epoll_ctl(epollfd, EPOLL_CTL_ADD, ctrl_sock.sock, &epev) == -1) {
        ALOGE("epoll_ctl for lmkd control socket failed (errno=%d)", errno);
        return -1;
    }
    maxevents++;

    has_inkernel_module = !access(INKERNEL_MINFREE_PATH, W_OK);
    use_inkernel_interface = has_inkernel_module;
    //使用内核空间的lowmemorykiller终止进程 
    if (use_inkernel_interface) {
        ALOGI("Using in-kernel low memory killer interface");
    } else {//使用用户空间的lmkd终止进程 
        if (!init_mp_common(VMPRESS_LEVEL_LOW) ||
            !init_mp_common(VMPRESS_LEVEL_MEDIUM) ||
            !init_mp_common(VMPRESS_LEVEL_CRITICAL)) {
            ALOGE("Kernel does not support memory pressure events or in-kernel low memory killer");
            return -1;
        }
    }
    //初始化双向链表
    for (i = 0; i <= ADJTOSLOT(OOM_SCORE_ADJ_MAX); i++) {
        procadjslot_list[i].next = &procadjslot_list[i];
        procadjslot_list[i].prev = &procadjslot_list[i];
    }

    return 0;
}
```

关于双向链表`procadjslot_list`,定义了指向前和后的指针,如下所示:

```c
struct adjslot_list {
    struct adjslot_list *next;
    struct adjslot_list *prev;
};
```

`procadjslot_list`从结构上看是双向链表，但定义形式又与数组类似，大小为ADJTOSLOT(OOM_SCORE_ADJ_MAX) + 1,经过转换,原来大小只为1(1000-1000+1).

```
/* OOM score values used by both kernel and framework */
#define OOM_SCORE_ADJ_MIN       (-1000)
#define OOM_SCORE_ADJ_MAX       1000
...
#define ADJTOSLOT(adj) ((adj) + -OOM_SCORE_ADJ_MIN)
static struct adjslot_list procadjslot_list[ADJTOSLOT(OOM_SCORE_ADJ_MAX) + 1];
```

当需要插入进程时，调用`proc_insert`:

```c
static void proc_insert(struct proc *procp) {
    //根据pid计算hash值
    int hval = pid_hashfn(procp->pid);
    //维护一个哈希链表，用于快速找到该进程,每次都放在该位置的头部
    procp->pidhash_next = pidhash[hval];
    pidhash[hval] = procp;
    //用procadjslot_list中放置该进程
    proc_slot(procp);
}

```

```c
static void proc_slot(struct proc *procp) {
    //计算进程需要放置的位置，将oomadj增加1000.
    int adjslot = ADJTOSLOT(procp->oomadj);
    //根据adjslot值，插入到procadjslot_list中，其实是类似一个优先队列的链表．优先级最高的放在头部，低的放在尾部．
    adjslot_insert(&procadjslot_list[adjslot], &procp->asl);
}
//将new插入到head位置之后
static void adjslot_insert(struct adjslot_list *head, struct adjslot_list *new)
{
    struct adjslot_list *next = head->next;
    new->prev = head;
    new->next = next;
    next->prev = new;
    head->next = new;
}
```

![](/img/bill/in-posts/2019-04-10/oomAdjLists.png)

### 2.2.5 mainloop()

当进入死循环后，先调用`epoll_wait`等待并阻塞，当接收到输入信号时，首先检查是否存在停止的socket连接，假如存在则首先执行其handle方法．第二步则遍历事件并进行处理．


```c
static void mainloop(void) {
    struct event_handler_info* handler_info;
    struct epoll_event *evt;

    while (1) {
        struct epoll_event events[maxevents];
        int nevents;
        int i;
        //阻塞等待epoll_event
        nevents = epoll_wait(epollfd, events, maxevents, -1);

        if (nevents == -1) {
            if (errno == EINTR)
                continue;
            ALOGE("epoll_wait failed (errno=%d)", errno);
            continue;
        }

        /*
         * First pass to see if any data socket connections were dropped.
         * Dropped connection should be handled before any other events
         * to deallocate data connection and correctly handle cases when
         * connection gets dropped and reestablished in the same epoll cycle.
         * In such cases it's essential to handle connection closures first.
         */
        for (i = 0, evt = &events[0]; i < nevents; ++i, evt++) {
            if ((evt->events & EPOLLHUP) && evt->data.ptr) {
                ALOGI("lmkd data connection dropped");
                handler_info = (struct event_handler_info*)evt->data.ptr;
                ctrl_data_close(handler_info->data);
            }
        }

        /* Second pass to handle all other events */
        for (i = 0, evt = &events[0]; i < nevents; ++i, evt++) {
            if (evt->events & EPOLLERR)
                ALOGD("EPOLLERR on event #%d", i);
            if (evt->events & EPOLLHUP) {
                /* This case was handled in the first pass */
                continue;
            }
            if (evt->data.ptr) {
                handler_info = (struct event_handler_info*)evt->data.ptr;
                handler_info->handler(handler_info->data, evt->events);
            }
        }
    }
}
```

当`epoll_wait`收到事件，并调用`ctrl_connect_handler`进行处理时，首先调用accept完成socket连接，紧接着新建一个监听输入事件，使用`ctrl_data_handler`来处理该输入事件．本地有一个`sock_event_handler_info`数组,大小为2,当连接建立前，将会检查哪个为空闲的，并予以使用．即lmkd最大支持同时连接2个客户端．

```
static void ctrl_connect_handler(int data __unused, uint32_t events __unused) {
    struct epoll_event epev;
    int free_dscock_idx = get_free_dsock();

    if (free_dscock_idx < 0) {
        /*
         * Number of data connections exceeded max supported. This should not
         * happen but if it does we drop all existing connections and accept
         * the new one. This prevents inactive connections from monopolizing
         * data socket and if we drop ActivityManager connection it will
         * immediately reconnect.
         */
        for (int i = 0; i < MAX_DATA_CONN; i++) {
            ctrl_data_close(i);
        }
        free_dscock_idx = 0;
    }

    data_sock[free_dscock_idx].sock = accept(ctrl_sock.sock, NULL, NULL);
    if (data_sock[free_dscock_idx].sock < 0) {
        ALOGE("lmkd control socket accept failed; errno=%d", errno);
        return;
    }

    ALOGI("lmkd data connection established");
    /* use data to store data connection idx */
    data_sock[free_dscock_idx].handler_info.data = free_dscock_idx;
    data_sock[free_dscock_idx].handler_info.handler = ctrl_data_handler;
    epev.events = EPOLLIN;
    epev.data.ptr = (void *)&(data_sock[free_dscock_idx].handler_info);
    if (epoll_ctl(epollfd, EPOLL_CTL_ADD, data_sock[free_dscock_idx].sock, &epev) == -1) {
        ALOGE("epoll_ctl for data connection socket failed; errno=%d", errno);
        ctrl_data_close(free_dscock_idx);
        return;
    }
    maxevents++;
}
```

可以做一个实验，在运行过程中，手动kill掉`system_server`(包含AMS)，此时打印出,即每次有epoll信号来时，首先检查是否存在断开的连接，并调用`ctrl_data_close`关闭连接．再查看是否有新的连接请求．

```
lowmemorykiller: lmkd data connection dropped
lowmemorykiller: closing lmkd data connection
lowmemorykiller: lmkd data connection established
```


## 2.3 lmkd处理传递信息


```c
static void ctrl_data_handler(int data, uint32_t events) {
    if (events & EPOLLIN) {
        ctrl_command_handler(data);
    }
}
```

`ctrl_command_handler`负责解析socket通信客户端发过来的信息，首先调用`ctrl_data_read`获取packet,并调用`lmkd_pack_get_cmd`解析出cmd，共分为三种:

1. LMK_TARGET: 更新内存级别以及对应别的进程adj
2. LMK_PROCPRIO: 根据pid更新adj
3. LMK_PROCREMOVE：根据pid移除proc

```c
static void ctrl_command_handler(int dsock_idx) {
    LMKD_CTRL_PACKET packet;
    int len;
    enum lmk_cmd cmd;
    int nargs;
    int targets;

    len = ctrl_data_read(dsock_idx, (char *)packet, CTRL_PACKET_MAX_SIZE);
    if (len <= 0)
        return;

    if (len < (int)sizeof(int)) {
        ALOGE("Wrong control socket read length len=%d", len);
        return;
    }

    cmd = lmkd_pack_get_cmd(packet);
    nargs = len / sizeof(int) - 1;
    if (nargs < 0)
        goto wronglen;

    switch(cmd) {
    case LMK_TARGET:
        targets = nargs / 2;
        if (nargs & 0x1 || targets > (int)ARRAY_SIZE(lowmem_adj))
            goto wronglen;
        cmd_target(targets, packet);
        break;
    case LMK_PROCPRIO:
        if (nargs != 3)
            goto wronglen;
        cmd_procprio(packet);
        break;
    case LMK_PROCREMOVE:
        if (nargs != 1)
            goto wronglen;
        cmd_procremove(packet);
        break;
    default:
        ALOGE("Received unknown command code %d", cmd);
        return;
    }

    return;

wronglen:
    ALOGE("Wrong control socket read length cmd=%d len=%d", cmd, len);
}
```

### 2.3.1 `LMK_TARGET`

`cmd_target`主要用于更新内存级别以及对应的进程adj．其逻辑如下:

1. 循环从packet中获取target，并解析出minfree与adj
2. 由于`has_inkernel_module`为true,将会使用内核逻辑处理，即将刚才从packet中的数据取出，并使用逗号分割，连接成字符串．最后分别写入到`"/sys/module/lowmemorykiller/parameters/minfree"和"/sys/module/lowmemorykiller/parameters/adj"`. 


```c
static void cmd_target(int ntargets, LMKD_CTRL_PACKET packet) {
    int i;
    struct lmk_target target;

    if (ntargets > (int)ARRAY_SIZE(lowmem_adj))
        return;

    for (i = 0; i < ntargets; i++) {
        lmkd_pack_get_target(packet, i, &target);
        lowmem_minfree[i] = target.minfree;
        lowmem_adj[i] = target.oom_adj_score;
    }

    lowmem_targets_size = ntargets;

    if (has_inkernel_module) {
        char minfreestr[128];
        char killpriostr[128];

        minfreestr[0] = '\0';
        killpriostr[0] = '\0';

        for (i = 0; i < lowmem_targets_size; i++) {
            char val[40];

            if (i) {
                strlcat(minfreestr, ",", sizeof(minfreestr));
                strlcat(killpriostr, ",", sizeof(killpriostr));
            }

            snprintf(val, sizeof(val), "%d", use_inkernel_interface ? lowmem_minfree[i] : 0);
            strlcat(minfreestr, val, sizeof(minfreestr));
            snprintf(val, sizeof(val), "%d", use_inkernel_interface ? lowmem_adj[i] : 0);
            strlcat(killpriostr, val, sizeof(killpriostr));
        }

        writefilestring(INKERNEL_MINFREE_PATH, minfreestr);
        writefilestring(INKERNEL_ADJ_PATH, killpriostr);
    }
}

```

如果cat上述提到的"/sys/module/lowmemorykiller/parameters/minfree"和"/sys/module/lowmemorykiller/parameters/adj"，分别得到的是如下数据:

```
minfree: 8192,10240,12288,14336,16384,20480
adj:     0,100,200,300,900,906
```

这两组数据是一一对应，如当内存小于20480时，就会杀死优先级在906以上的进程，以此类推．

那么进程的优先级，可以通过`/proc/[pid]/oom_adj`中查看，但该优先级是内核优先级，上层优先级可以看`/proc/[pid]/oom_score_adj`.其换算关系:

```c
//drivers/staging/android/lowmemorykiller.c
static short lowmem_oom_adj_to_oom_score_adj(short oom_adj)
{
	if (oom_adj == OOM_ADJUST_MAX)
		return OOM_SCORE_ADJ_MAX;
	else
		return (oom_adj * OOM_SCORE_ADJ_MAX) / -OOM_DISABLE;
}
```

`OOM_SCORE_ADJ_MAX`为1000,`OOM_DISABLE`的值为-17，以init进程为例，在启动时，`oom_score_adj`设置为-1000,推算出其`oom_adj`为-17.
```
on early-init
    # Set init and its forked children's oom_adj.
    write /proc/1/oom_score_adj -1000
```

在实际操作中，可以通过串口将某一进程的`oom_adj`进行改变，观察`oom_score_adj`也会随着这个转换式进行改变．反之亦然．


Android将所有进程划归如下表,具体可以参考frameworks/base/java/com/android/server/am/ProcessList.java

|type|OOM_SCORE_ADJ|ADJ|Description|
|--|--|--|--|
|Native|-1000|-17|Native进程|
|System|-900|-15|系统进程|
|Persistent|-800|-13|Persistent性质进程|
|Persistent Service|-700|-11|绑定了(bind)System进程或者Persistent的进程|
|Foreground|0|0|前台运行的进程,即用户当前交互的进程|
|Visible|100|1|有前台可见的Activity进程，杀死该类进程将影响用户体验|
|Perceptible|200|3|该类进程不可见，但能被用户感知，如后台音乐播放器|
|Backup|300|5|用于承载backup操作的进程|
|Heavy|400|6|重量级应用进程|
|Service|500|8|当前运行了Application service的进程|
|Home|600|10|Launcher进程|
|Previous|700|11|用户前一次交互的进程|
|Service B|800|13|startService()且进程不包含Activity|
|Cached|900-906|15|缓存进程,当前运行了不可见的Activity|
|Unknown|1001||未知的adj|

以实际实验为例，测试如下,符合上述表

1. SurfaceFlinger: `oom_adj` = -17
2. Zygote: `oom_adj` = -17
3. SystemServer: `oom_adj` = -15
4. Launcher:交互时为0,非交互时为10
5. 输入法: 非交互时为3,交互时为1
6. music：打开时为0,返回桌面不可见且暂停播放时为15，后台播放时为3

回过头来看，当上层AMS通过ProcessList调用updateOomLevels接口时，会首先分配内存，大小为4 * (2*mOomAdj.length + 1),因为传递的内容包括一个类型(`LMK_TARGET`)以及两组mOomAdj长的数据，分别放minfree以及adj.最后通过writeLmkd发送到LMKD中处理．

```java
//ProcessList.updateOomLevels
if (write) {
    ByteBuffer buf = ByteBuffer.allocate(4 * (2*mOomAdj.length + 1));
    buf.putInt(LMK_TARGET);
    for (int i=0; i<mOomAdj.length; i++) {
        buf.putInt((mOomMinFree[i]*1024)/PAGE_SIZE);
        buf.putInt(mOomAdj[i]);
    }
    writeLmkd(buf);
    SystemProperties.set("sys.sysctl.extra_free_kbytes", Integer.toString(reserve));
}
```

writeLmkd将会最多尝试4次，打开Lmkd的socket套接口，并将数据写入到该socket，直至发送到lmkd中．

```java
private static void writeLmkd(ByteBuffer buf) {
    for (int i = 0; i < 3; i++) {
        if (sLmkdSocket == null) {
                if (openLmkdSocket() == false) {
                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException ie) {
                    }
                    continue;
                }
        }

        try {
            sLmkdOutputStream.write(buf.array(), 0, buf.position());
            return;
        } catch (IOException ex) {
            Slog.w(TAG, "Error writing to lowmemorykiller socket");
            try {
                sLmkdSocket.close();
            } catch (IOException ex2) {
            }
            sLmkdSocket = null;
        }
    }
}
```

### 2.3.2 `cmd_procprio`

`cmd_procprio`的主要作用是更新进程的的adj,首先通过`lmkd_pack_get_procprio`将packet解释为`lmk_procprio`类型的数据，该数据类型包括pid,uid以及adj,接着检查需要设置的adj是否在范围以内，最后写入到`"/proc/[pid]/oom_score_adj"`．至此如果是使用内核逻辑的话，就会返回．否则还会进行进一步处理．假如是`low_ram_device`,还会去更新`soft_limit_mult`到`/dev/memcg/apps/uid_%d/pid_%d/memory.soft_limit_in_byte`.最后还会通过调用`pid_lookup`在哈希表中是否存在该进程，假如不存在，则将进程加入到双向链表中，否则将该进程移出，并重新加入到双向链表中的头部．

```c
static void cmd_procprio(LMKD_CTRL_PACKET packet) {
    struct proc *procp;
    char path[80];
    char val[20];
    int soft_limit_mult;
    struct lmk_procprio params;

    lmkd_pack_get_procprio(packet, &params);

    if (params.oomadj < OOM_SCORE_ADJ_MIN ||
        params.oomadj > OOM_SCORE_ADJ_MAX) {
        ALOGE("Invalid PROCPRIO oomadj argument %d", params.oomadj);
        return;
    }

    snprintf(path, sizeof(path), "/proc/%d/oom_score_adj", params.pid);
    snprintf(val, sizeof(val), "%d", params.oomadj);
    writefilestring(path, val);

    if (use_inkernel_interface)
        return;

    if (low_ram_device) {
        if (params.oomadj >= 900) {
            soft_limit_mult = 0;
        } else if (params.oomadj >= 800) {
            soft_limit_mult = 0;
        } else if (params.oomadj >= 700) {
            soft_limit_mult = 0;
        } else if (params.oomadj >= 600) {
            // Launcher should be perceptible, don't kill it.
            params.oomadj = 200;
            soft_limit_mult = 1;
        } else if (params.oomadj >= 500) {
            soft_limit_mult = 0;
        } else if (params.oomadj >= 400) {
            soft_limit_mult = 0;
        } else if (params.oomadj >= 300) {
            soft_limit_mult = 1;
        } else if (params.oomadj >= 200) {
            soft_limit_mult = 2;
        } else if (params.oomadj >= 100) {
            soft_limit_mult = 10;
        } else if (params.oomadj >=   0) {
            soft_limit_mult = 20;
        } else {
            // Persistent processes will have a large
            // soft limit 512MB.
            soft_limit_mult = 64;
        }
        //当使用low_ram_device时，会根据进程的oomadj进行分级，从而确定soft_limit_multi的值
        //最后将soft_limit_multi * EIGHT_MEGA(8MB)的值写入到memory.soft_limit_in_bytes，
        //soft_limit_in_bytes不会像limit_in_bytes组织进程使用超过限额的内存，但会在系统内存不足时，
        //有限回收超过限额的进程占用的内存．
        snprintf(path, sizeof(path),
             "/dev/memcg/apps/uid_%d/pid_%d/memory.soft_limit_in_bytes",
             params.uid, params.pid);
        snprintf(val, sizeof(val), "%d", soft_limit_mult * EIGHT_MEGA);
        writefilestring(path, val);
    }
    //当不使用内核空间lowmemorykiller时，将该进程加入到链表中
    procp = pid_lookup(params.pid);
    if (!procp) {
            procp = malloc(sizeof(struct proc));
            if (!procp) {
                // Oh, the irony.  May need to rebuild our state.
                return;
            }
            procp->pid = params.pid;
            procp->uid = params.uid;
            procp->oomadj = params.oomadj;
            proc_insert(procp);
    } else {
        proc_unslot(procp);
        procp->oomadj = params.oomadj;
        proc_slot(procp);
    }
}
```

对应到上层ProcessList的setOomAdj方法，与updateOomLevels类似，通过socket发送byteBuffer到lmkd中进行处理．

```java
public static final void setOomAdj(int pid, int uid, int amt) {
    // This indicates that the process is not started yet and so no need to proceed further.
    if (pid <= 0) {
        return;
    }
    if (amt == UNKNOWN_ADJ)
        return;

    long start = SystemClock.elapsedRealtime();
    ByteBuffer buf = ByteBuffer.allocate(4 * 4);
    buf.putInt(LMK_PROCPRIO);
    buf.putInt(pid);
    buf.putInt(uid);
    buf.putInt(amt);
    writeLmkd(buf);
    long now = SystemClock.elapsedRealtime();
    if ((now-start) > 250) {
        Slog.w("ActivityManager", "SLOW OOM ADJ: " + (now-start) + "ms for pid " + pid
                + " = " + amt);
    }
}
```

### 2.3.3 `cmd_procremove`

`cmd_procremove`的逻辑更为简单，使用内核逻辑的就直接不处理，不使用内核的则从双向链表中去除相关的元素．

```c
static void cmd_procremove(LMKD_CTRL_PACKET packet) {
    struct lmk_procremove params;

    if (use_inkernel_interface)
        return;

    lmkd_pack_get_procremove(packet, &params);
    pid_remove(params.pid);
}
```

与之对应的ProcessList方法为:

```java
public static final void remove(int pid) {
    // This indicates that the process is not started yet and so no need to proceed further.
    if (pid <= 0) {
        return;
    }
    ByteBuffer buf = ByteBuffer.allocate(4 * 2);
    buf.putInt(LMK_PROCREMOVE);
    buf.putInt(pid);
    writeLmkd(buf);
}
```

### 2.3.4 小结

从以上分析来看，当内核空间lowmemorykiller工作时，lmkd只是一个类似中转站，将AMS的指令通过更新minfree,adj节点，或者是更新指定pid的oomAdj传达到内核空间中．但如果是在用户空间lmkd工作时，则会动态维护一个链表，为之后的终止进程做准备．

## 2.4 lmkd杀进程流程

使用内核空间时，lmkd不会主动去杀进程，那么在用户空间的lmkd是如何去杀进程的呢？

首先在init阶段，调用`init_mp_common`.这里的逻辑是从`VMPRESS_LEVEL_LOW`到`VMPRESS_LEVEL_MEDIUM`到最后`VMPRESS_LEVEL_CRITICAL`从底到高分别尝试．

```c
if (use_inkernel_interface) {
    ALOGI("Using in-kernel low memory killer interface");
} else {
    if (!init_mp_common(VMPRESS_LEVEL_LOW) ||
        !init_mp_common(VMPRESS_LEVEL_MEDIUM) ||
        !init_mp_common(VMPRESS_LEVEL_CRITICAL)) {
        ALOGE("Kernel does not support memory pressure events or in-kernel low memory killer");
        return -1;
}
```

`init_mp_common`做了如下逻辑:

1. 打开节点`/dev/memcg/memory.pressure_level`，待读取.
2. 打开节点`/dev/memcg/cgroup.event_control`,待写入.
3. 创建一个非阻塞的eventfd用于事件通知. 
4. 新建一个buf,将刚才创建的fd(事件通知fd,`pressure_level`fd,参数level)一并放进去.
5. 将buf写入到刚才创建待写入的节点`event_control`中．
6. epoll中加入一个新的监听输入事件，handler指向`mp_event_common`.当evnetfd有事件过来时，则会触发到回调函数.

```c
static bool init_mp_common(enum vmpressure_level level) {
    int mpfd;
    int evfd;
    int evctlfd;
    char buf[256];
    struct epoll_event epev;
    int ret;
    int level_idx = (int)level;
    const char *levelstr = level_name[level_idx];
    //打开pressure_level节点
    mpfd = open(MEMCG_SYSFS_PATH "memory.pressure_level", O_RDONLY | O_CLOEXEC);
    if (mpfd < 0) {
        ALOGI("No kernel memory.pressure_level support (errno=%d)", errno);
        goto err_open_mpfd;
    }
    //打开cgroup.event_controll节点
    evctlfd = open(MEMCG_SYSFS_PATH "cgroup.event_control", O_WRONLY | O_CLOEXEC);
    if (evctlfd < 0) {
        ALOGI("No kernel memory cgroup event control (errno=%d)", errno);
        goto err_open_evctlfd;
    }

    evfd = eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
    if (evfd < 0) {
        ALOGE("eventfd failed for level %s; errno=%d", levelstr, errno);
        goto err_eventfd;
    }

    ret = snprintf(buf, sizeof(buf), "%d %d %s", evfd, mpfd, levelstr);
    if (ret >= (ssize_t)sizeof(buf)) {
        ALOGE("cgroup.event_control line overflow for level %s", levelstr);
        goto err;
    }

    ret = TEMP_FAILURE_RETRY(write(evctlfd, buf, strlen(buf) + 1));
    if (ret == -1) {
        ALOGE("cgroup.event_control write failed for level %s; errno=%d",
              levelstr, errno);
        goto err;
    }

    epev.events = EPOLLIN;
    /* use data to store event level */
    vmpressure_hinfo[level_idx].data = level_idx;
    vmpressure_hinfo[level_idx].handler = mp_event_common;
    epev.data.ptr = (void *)&vmpressure_hinfo[level_idx];
    ret = epoll_ctl(epollfd, EPOLL_CTL_ADD, evfd, &epev);
    if (ret == -1) {
        ALOGE("epoll_ctl for level %s failed; errno=%d", levelstr, errno);
        goto err;
    }
    maxevents++;
    mpevfd[level] = evfd;
    close(evctlfd);
    return true;

err:
    close(evfd);
err_eventfd:
    close(evctlfd);
err_open_evctlfd:
    close(mpfd);
err_open_mpfd:
    return false;
}
```

至此，`mp_event_common`正式处理杀进程的逻辑:

```c
static void mp_event_common(int data, uint32_t events __unused) {
    int ret;
    unsigned long long evcount;
    int64_t mem_usage, memsw_usage;
    int64_t mem_pressure;
    enum vmpressure_level lvl;
    union meminfo mi;
    union zoneinfo zi;
    static struct timeval last_report_tm;
    static unsigned long skip_count = 0;
    enum vmpressure_level level = (enum vmpressure_level)data;
    long other_free = 0, other_file = 0;
    int min_score_adj;
    int pages_to_free = 0;
    int minfree = 0;
    static struct reread_data mem_usage_file_data = {
        .filename = MEMCG_MEMORY_USAGE,
        .fd = -1,
    };
    static struct reread_data memsw_usage_file_data = {
        .filename = MEMCG_MEMORYSW_USAGE,
        .fd = -1,
    };

    /*
    从低到高读取mpevfd，更新其计数器.
    */ 
    for (lvl = VMPRESS_LEVEL_LOW; lvl < VMPRESS_LEVEL_COUNT; lvl++) {
        if (mpevfd[lvl] != -1 &&
            TEMP_FAILURE_RETRY(read(mpevfd[lvl],
                               &evcount, sizeof(evcount))) > 0 &&
            evcount > 0 && lvl > level) {
            level = lvl;
        }
    }
   
   //假如设置了`kill_timeout_ms`,那么计算当前时间到上次调用`mp_event_common`时记录的时间差和`kill_timeout_ms`进行对比，
   //如果没到达该时间,则递增`skip_count`并自增后返回,注意`skip_count`是静态量．
   if (kill_timeout_ms) {
        struct timeval curr_tm;
        gettimeofday(&curr_tm, NULL);
        if (get_time_diff_ms(&last_report_tm, &curr_tm) < kill_timeout_ms) {
            skip_count++;
            return;
        }
    }
    //超过了`kill_timeout_ms`时间，重新清零．
    if (skip_count > 0) {
        ALOGI("%lu memory pressure events were skipped after a kill!",
              skip_count);
        skip_count = 0;
    }
   
   /*
    meminfo_parse解析/proc/meminfo的内容，并获取如下数据：
    "MemFree:": 系统尚未使用的内存,LowFree和HightFree的总和
    "Cached:": 被高速缓冲存储器用的内存大小
    "SwapCached:": 被高速缓冲存储器用的交换空间的大小 
    "Buffers:": 用来给文件做缓冲大小
    "Shmem:": 共享内存
    "Unevictable:",不能够pageout/swapout的内存页
    "SwapFree:"：未被使用交换空间的大小
    "Dirty: 等待被写回到磁盘的内存大小
    
    zoneinfo_parse解析"/proc/zoneinfo"的内容，并获取如下数据
   "nr_free_pages",
    "nr_file_pages",
    "nr_shmem",
    "nr_unevictable",
    "workingset_refault",
    "high",`
   */
    if (meminfo_parse(&mi) < 0 || zoneinfo_parse(&zi) < 0) {
        ALOGE("Failed to get free memory!");
        return;
    }
    //use_minfree_levels的逻辑和内核相同
    //该模式下，需要借助可用内存和文件换存阈值来决定何时终止
    if (use_minfree_levels) {
        int i;
        //other_free为可用内存，为MemFree(meminfo)的值减去计算出来的totalreserve_pages（page_high）
        other_free = mi.field.nr_free_pages - zi.field.totalreserve_pages;
        if (mi.field.nr_file_pages > (mi.field.shmem + mi.field.unevictable + mi.field.swap_cached)) {
            //other_file为文件换存阈值，为MemTotal-Shemem-unevictable-swapcached
            other_file = (mi.field.nr_file_pages - mi.field.shmem -
                          mi.field.unevictable - mi.field.swap_cached);
        } else {
            other_file = 0;
        }
        //从低到高遍历，当other_free和other_file均满足小于minfree时，跳出
        //找到对应lowmem_adj数组的min_score_adj.
        min_score_adj = OOM_SCORE_ADJ_MAX + 1;
        for (i = 0; i < lowmem_targets_size; i++) {
            minfree = lowmem_minfree[i];
            if (other_free < minfree && other_file < minfree) {
                min_score_adj = lowmem_adj[i];
                break;
            }
        }

        if (min_score_adj == OOM_SCORE_ADJ_MAX + 1) {
            if (debug_process_killing) {
                ALOGI("Ignore %s memory pressure event "
                      "(free memory=%ldkB, cache=%ldkB, limit=%ldkB)",
                      level_name[level], other_free * page_k, other_file * page_k,
                      (long)lowmem_minfree[lowmem_targets_size - 1] * page_k);
            }
            return;
        }
        //计算出需要释放的内存大小
        /* Free up enough pages to push over the highest minfree level */
        pages_to_free = lowmem_minfree[lowmem_targets_size - 1] -
            ((other_free < other_file) ? other_free : other_file);
        goto do_kill;
    }
    
    if (level == VMPRESS_LEVEL_LOW) {
        record_low_pressure_levels(&mi);
    }

    if (level_oomadj[level] > OOM_SCORE_ADJ_MAX) {
        /* Do not monitor this pressure level */
        return;
    }
    //从/dev/memcg/memory.usage_in_bytes获取已用的内存
    if ((mem_usage = get_memory_usage(&mem_usage_file_data)) < 0) {
        goto do_kill;
    }
    //从/dev/memcg/memory.memsw.usage_in_bytes获取已用的内存
    if ((memsw_usage = get_memory_usage(&memsw_usage_file_data)) < 0) {
        goto do_kill;
    }
    // Calculate percent for swappinness.
    //计算出交换率
    mem_pressure = (mem_usage * 100) / memsw_usage;

    if (enable_pressure_upgrade && level != VMPRESS_LEVEL_CRITICAL) {
        // We are swapping too much.
        if (mem_pressure < upgrade_pressure) {
            level = upgrade_level(level);
            if (debug_process_killing) {
                ALOGI("Event upgraded to %s", level_name[level]);
            }
        }
    }

    // If the pressure is larger than downgrade_pressure lmk will not
    // kill any process, since enough memory is available.
    if (mem_pressure > downgrade_pressure) {
        if (debug_process_killing) {
            ALOGI("Ignore %s memory pressure", level_name[level]);
        }
        return;
    } else if (level == VMPRESS_LEVEL_CRITICAL &&
               mem_pressure > upgrade_pressure) {
        if (debug_process_killing) {
            ALOGI("Downgrade critical memory pressure");
        }
        // Downgrade event, since enough memory available.
        level = downgrade_level(level);
    }
...
```

具体执行终止程序的操作：

```
...
do_kill:
    if (low_ram_device) {
        /* For Go devices kill only one task */
        if (find_and_kill_processes(level, level_oomadj[level], 0) == 0) {
            if (debug_process_killing) {
                ALOGI("Nothing to kill");
            }
        }
    } else {
        int pages_freed;
        ...
        //执行杀进程操作
        //min_score_adj值为level_oomadj[level]
        pages_freed = find_and_kill_processes(level, min_score_adj, pages_to_free);
        ...
        if (pages_freed < pages_to_free) {
            ALOGI("Unable to free enough memory (pages to free=%d, pages freed=%d)",
                  pages_to_free, pages_freed);
        } else {
            ALOGI("Reclaimed enough memory (pages to free=%d, pages freed=%d)",
                  pages_to_free, pages_freed);
            //更新操作时间
            gettimeofday(&last_report_tm, NULL);
        }
    }
}
```

```
static int find_and_kill_processes(enum vmpressure_level level,
                                   int min_score_adj, int pages_to_free) {
    int i;
    int killed_size;
    int pages_freed = 0;

    for (i = OOM_SCORE_ADJ_MAX; i >= min_score_adj; i--) {
        struct proc *procp;
        //通过kill_one_process杀死进程，
        //可以通过proc_get_heaviest或者proc_adj_lru两种方法获取该杀死的进程
        while (true) {
            procp = kill_heaviest_task ?
                proc_get_heaviest(i) : proc_adj_lru(i);
            if (!procp)
                break;
            killed_size = kill_one_process(procp, min_score_adj, level);
            if (killed_size >= 0) {
                pages_freed += killed_size;
                if (pages_freed >= pages_to_free) {
                    return pages_freed;
                }
            }
        }
    }
   return pages_freed;
}
```

`proc_get_heaviest`是遍历双向链表中的内容，并读取/proc/[pid]/statm的数值，选取最大值的一个
```c
static struct proc *proc_get_heaviest(int oomadj) {
    struct adjslot_list *head = &procadjslot_list[ADJTOSLOT(oomadj)];
    struct adjslot_list *curr = head->next;
    struct proc *maxprocp = NULL;
    int maxsize = 0;
    while (curr != head) {
        int pid = ((struct proc *)curr)->pid;
        int tasksize = proc_get_size(pid);
        if (tasksize <= 0) {
            struct adjslot_list *next = curr->next;
            pid_remove(pid);
            curr = next;
        } else {
            if (tasksize > maxsize) {
                maxsize = tasksize;
                maxprocp = (struct proc *)curr;
            }
            curr = curr->next;
        }
    }
    return maxprocp;
}

static int proc_get_size(int pid) {
    char path[PATH_MAX];
    char line[LINE_MAX];
    int fd;
    int rss = 0;
    int total;
    ssize_t ret;

    snprintf(path, PATH_MAX, "/proc/%d/statm", pid);
    fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd == -1)
        return -1;

    ret = read_all(fd, line, sizeof(line) - 1);
    if (ret < 0) {
        close(fd);
        return -1;
    }

    sscanf(line, "%d %d ", &total, &rss);
    close(fd);
    return rss;
}
```

获取双向链表的尾部进程，由于双向链表的排列是按照oomadj进行排列，因此值大即低优先级的在队列的尾部,也是首先被处理的进程．
```c
static struct proc *proc_adj_lru(int oomadj) {
    return (struct proc *)adjslot_tail(&procadjslot_list[ADJTOSLOT(oomadj)]);
}
```

`kill_one_process`最终调用到kill来杀死进程，并从双向链表中去掉该进程．

```c
static int kill_one_process(struct proc* procp, int min_score_adj,
                            enum vmpressure_level level) {
    int pid = procp->pid;
    uid_t uid = procp->uid;
    char *taskname;
    int tasksize;
    int r;

    taskname = proc_get_name(pid);
    if (!taskname) {
        pid_remove(pid);
        return -1;
    }

    tasksize = proc_get_size(pid);
    if (tasksize <= 0) {
        pid_remove(pid);
        return -1;
    }

    TRACE_KILL_START(pid);

    r = kill(pid, SIGKILL);
    ... 
    pid_remove(pid);

    if (r) {
        ALOGE("kill(%d): errno=%d", pid, errno);
        return -1;
    } else {
        return tasksize;
    }
    return tasksize;
}
```

## 2.5 kernel lowmemorykiller

更多情况下，lmkd是借助于kernel的lowmemorykiller来杀进程的,现进行分析:

### 2.5.1 kernel lowmemorykiller初始化

```c
static struct shrinker lowmem_shrinker = {
	.scan_objects = lowmem_scan,
	.count_objects = lowmem_count,
	.seeks = DEFAULT_SEEKS * 16
};

static int __init lowmem_init(void)
{
	register_shrinker(&lowmem_shrinker);
	return 0;
}
device_initcall(lowmem_init);
```

### 2.5.2 kernel `lowmem_shrinker` 

```c
static unsigned long lowmem_scan(struct shrinker *s, struct shrink_control *sc)
{
	struct task_struct *tsk;
	struct task_struct *selected = NULL;
	unsigned long rem = 0;
	int tasksize;
	int i;
	short min_score_adj = OOM_SCORE_ADJ_MAX + 1;
	int minfree = 0;
	int selected_tasksize = 0;
	short selected_oom_score_adj;
	int array_size = ARRAY_SIZE(lowmem_adj);
	//获取当前系统剩余内存和文件缓存阈值，与用户空间开启use_min_freelevel逻辑相同
	int other_free = global_page_state(NR_FREE_PAGES) - totalreserve_pages;
	int other_file = global_node_page_state(NR_FILE_PAGES) -
				global_node_page_state(NR_SHMEM) -
				global_node_page_state(NR_UNEVICTABLE) -
				total_swapcache_pages();

	if (lowmem_adj_size < array_size)
		array_size = lowmem_adj_size;
	if (lowmem_minfree_size < array_size)
		array_size = lowmem_minfree_size;
    //从小到大递增计算minfree，当临界点minfree大于剩余内存other_free时，计算出对应的adj
    //保存到min_score_adj中
	for (i = 0; i < array_size; i++) {
		minfree = lowmem_minfree[i];
		if (other_free < minfree && other_file < minfree) {
			min_score_adj = lowmem_adj[i];
			break;
		}
	}
    ...
	if (min_score_adj == OOM_SCORE_ADJ_MAX + 1) {
		lowmem_print(5, "lowmem_scan %lu, %x, return 0\n",
			     sc->nr_to_scan, sc->gfp_mask);
		return 0;
	}

	selected_oom_score_adj = min_score_adj;

	rcu_read_lock();
	//遍历所有进程
	for_each_process(tsk) {
		struct task_struct *p;
		short oom_score_adj;
        //内核线程跳过
		if (tsk->flags & PF_KTHREAD)
			continue;

		p = find_lock_task_mm(tsk);
		if (!p)
			continue;

		if (task_lmk_waiting(p) &&
		    time_before_eq(jiffies, lowmem_deathpending_timeout)) {
			task_unlock(p);
			rcu_read_unlock();
			return 0;
		}
		oom_score_adj = p->signal->oom_score_adj;
		if (oom_score_adj < min_score_adj) {
			task_unlock(p);
			continue;
		}
		tasksize = get_mm_rss(p->mm);
		task_unlock(p);
		if (tasksize <= 0)
			continue;
		if (selected) {
		    //当selected不为空，即选择了进程，会比较该进程的oom_score_adj
		    //如果当前进程的oom_score_adj与选中的进程的oom_score_adj相比较小，则跳过．说明当前进程优先级较高
		    //或者相同时，如果tasksize更小时，也跳过．
			if (oom_score_adj < selected_oom_score_adj)
				continue;
			if (oom_score_adj == selected_oom_score_adj &&
			    tasksize <= selected_tasksize)
				continue;
		}
		selected = p;
		selected_tasksize = tasksize;
		selected_oom_score_adj = oom_score_adj;
		lowmem_print(2, "select '%s' (%d), adj %hd, size %d, to kill\n",
			     p->comm, p->pid, oom_score_adj, tasksize);
	}
	if (selected) {
		long cache_size = other_file * (long)(PAGE_SIZE / 1024);
		long cache_limit = minfree * (long)(PAGE_SIZE / 1024);
		long free = other_free * (long)(PAGE_SIZE / 1024);

		task_lock(selected);
		//发送kill信号给进程
		send_sig(SIGKILL, selected, 0);
		if (selected->mm)
			task_set_lmk_waiting(selected);
		task_unlock(selected);
		trace_lowmemory_kill(selected, cache_size, cache_limit, free);
		lowmem_print(1, "Killing '%s' (%d) (tgid %d), adj %hd,\n"
				 "   to free %ldkB on behalf of '%s' (%d) because\n"
				 "   cache %ldkB is below limit %ldkB for oom_score_adj %hd\n"
				 "   Free memory is %ldkB above reserved\n",
			     selected->comm, selected->pid, selected->tgid,
			     selected_oom_score_adj,
			     selected_tasksize * (long)(PAGE_SIZE / 1024),
			     current->comm, current->pid,
			     cache_size, cache_limit,
			     min_score_adj,
			     free);
		lowmem_deathpending_timeout = jiffies + HZ;
		rem += selected_tasksize;
	}

	lowmem_print(4, "lowmem_scan %lu, %x, return %lu\n",
		     sc->nr_to_scan, sc->gfp_mask, rem);
	rcu_read_unlock();
	return rem;
}
```

# 3 小结

lmkd会在系统内存低的时候，选择合适的进程进行内存回收，这里会涉及到使用内核或者不使用内核两种．但两者的思路都是类似的，即根据当前剩余的内存，在minfree中找到当前的等级,并根据等级找到adj,选择符合标准的进程进行回收．
