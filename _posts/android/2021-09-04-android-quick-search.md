---
layout:     post
title:      "Android Debug总结"
subtitle:    "记录一些Android平时使用的工具和调试手段"
summary:    '"记录一些Android平时使用的工具和调试手段"'
date:       2021-09-04 23:42:11
author:     "Bill"
header-img: "img/bill/header-posts/2021-09-04-header.jpg"
catalog: true
tags:
    - default
---


<!-- vim-markdown-toc GFM -->

* [1. logcat](#1-logcat)
* [2. gdb](#2-gdb)
* [3. addr2line](#3-addr2line)
* [4. systrace](#4-systrace)
    * [4.1 保存trace到文件](#41-保存trace到文件)
* [5. 网络ADB](#5-网络adb)

<!-- vim-markdown-toc -->

# 1. logcat

```
logcat -c //清除日志
logcat -b [main|system|events] //选择不同的缓冲区
logcat -f xxx.log　//输出到文件
logcat -n <count> -r <kbytes> //-n指定日志数量，-r指定文件大小
logcat -v <format> //指定logcat输出格式，包括brief,process,threadtime,tag,raw,long等等
logcat -t "01-14 16:00:00.000" //输出指定时间到最近的日志
logcat -t 10 //输出最近10条日志
logcat | grep -i xxxx -A 10 -B 10//搜索关键字附近各10行的内容
logcat | grep -ivE "A_tag|B_tag|C_tag"  //假如需要排除多个tag的打印，也可以通过grep去过滤:
logcat | tee /data/logcat.txt //甚至可以同时输出logcat到屏幕并保存内容到文件中
```

# 2. gdb

```
gdbserver :[tcp port] [--attach [pid] || [binary file]]
# 进入adb shell
adb forward tcp:[tcp port] tcp:[tcp port]
target remote localhost:[tcp port]
```

# 3. addr2line

日常遇到Native层崩溃时，可以通过函数地址转换成具体的文件行数或函数名

```
addr2line  -f -C -e  [地址]
# -f: --functions：在显示文件名、行号输出信息的同时显示函数名信息
# -C: --demangle[=style]：将低级别的符号名解码为用户级别的名字。
# -e: --exe=<executable>：指定需要转换地址的可执行文件名。
```

# 4. systrace

## 4.1 保存trace到文件

```
# 使用atrace保存文件到本地
adb shell atrace -z -b 40000 gfx input view wm rs sched freq idle disk video -t 30 > ${TRACE_OUT_PATH}
# 使用SDK中的systrace将trace保存为可视化html文件
systrace.py --from-file ${TRACE_OUT_PATH} -o ${OUTPUT_HTML}
```

其中列表包括:

```
gfx - Graphics
input - Input
view - View System
webview - WebView
wm - Window Manager
am - Activity Manager
sm - Sync Manager
audio - Audio
video - Video
camera - Camera
hal - Hardware Modules
app - Application
res - Resource Loading
dalvik - Dalvik VM
rs - RenderScript
bionic - Bionic C Library
power - Power Management
pm - Package Manager
ss - System Server
database - Database
network - Network
adb - ADB
pdx - PDX services
sched - CPU Scheduling
irq - IRQ Events
i2c - I2C Events
freq - CPU Frequency
idle - CPU Idle
disk - Disk I/O
mmc - eMMC commands
workq - Kernel Workqueues
regulators - Voltage and Current Regulators
binder_driver - Binder Kernel driver
binder_lock - Binder global lock trace
pagecache - Page cache
```

# 5. 网络ADB

```
# 将设备连接PC，设置端口
1. adb tcpip 5555
2. adb shell ip addr show wlan0
3. adb connect [ip]:5555
```

