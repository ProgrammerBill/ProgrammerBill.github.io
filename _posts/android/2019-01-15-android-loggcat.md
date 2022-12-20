---
layout:     post
title:      "Android logcat工具简析"
summary:    '"Android log"'
date:       2019-01-15 10:43:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-01-15.jpg"
catalog: true
tags:
    - android
---


<!-- vim-markdown-toc GFM -->

* [1. 前言](#1-前言)
* [2.logcatd](#2logcatd)
	* [2.1 logcat常用命令](#21-logcat常用命令)
	* [2.2 logcatd.rc](#22-logcatdrc)
	* [2.3 `logcat_main`](#23-logcat_main)
	* [2.3.1 `android_logat_context`初始化](#231-android_logat_context初始化)
		* [2.3.2 `android_logcat_run_command`](#232-android_logcat_run_command)
		* [2.3.3 `log_msg`读取流程](#233-log_msg读取流程)

<!-- vim-markdown-toc -->

# 1. 前言

logcat是调试中重要的利器，通过logcat能够分析当前的应用行为。而为了在系统层面上记录信息，一般会在后台调用logcat记录日志。在4.4当时还没有logcatd的后台程序，于是会将在init下配置脚本文件记录logcat以及内核日志，当出问题的时候可以追查。而有了logcatd后，该服务会循环的将日志记录在/data/misc/logd/logcat目录下，每份日志为1M,最多记录256M文件。

# 2.logcatd

## 2.1 logcat常用命令

研究logcatd有助与分析logcat的行为，平时使用logcat的命令并没有十分复杂，常用的包括:

```
logcat -c //清除日志
logcat -b [main|system|events] //选择不同的缓冲区
logcat -f xxx.log　//输出到文件
logcat -n <count> -r <kbytes> //-n指定日志数量，-r指定文件大小
logcat -v <format> //指定logcat输出格式，包括brief,process,threadtime,tag,raw,long等等
logcat -t "01-14 16:00:00.000" //输出指定时间到最近的日志
logcat -t 10 //输出最近10条日志
```

当然也可以搜索关键字，并结合grep来搜索：

```
logcat | grep -i xxxx -A 10 -B 10//搜索关键字附近各10行的内容
```

假如需要排除多个tag的打印，也可以通过grep去过滤:

```
logcat | grep -ivE "A_tag|B_tag|C_tag"
```

甚至可以同时输出logcat到屏幕并保存内容到文件中:

```
logcat | tee /data/logcat.txt
```

## 2.2 logcatd.rc

logcatd.rc的内容如下:

```
service logcatd /system/bin/logcatd -L -b ${logd.logpersistd.buffer:-all} -v threadtime -v usec -v printable -D -f /data/misc/logd/logcat -r 1024 -n ${logd.logpersistd.size:-256} --id=${ro.build.id}
    class late_start
    disabled
    # logd for write to /data/misc/logd, log group for read from log daemon
    user logd
    group log
    writepid /dev/cpuset/system-background/tasks
    oom_score_adjust -600
```

首先logcat的参数大致都能够理解，假如相关的属性没有定义logd.logpersistd.buffer和logd.logpersistd.size，那么单个文件的大小设置为1M(1024KB),数量最多为256个，否则会循环覆盖，最新的日志为logcat,次新的为logcat.001,如此类推。-b all指明所有缓冲区都记录。-v后跟usec使得时间精度更高。logcatd的启动时机在`late_start`,单加上了disabled属性，即该服务默认该是不启动的。有趣的是,启动流程中logcatd把其pid卸载了`/dev/cpuset/system-background/tasks`中，cat该文件得到的也与logcatd的pid相吻合。`oom_score_adjust`设置为-600不容易被lowMemoryKiller杀死。

该服务默认没有开启，可以通过start logcatd开启服务，也可以设置属性开启服务，如:

```
on property:logd.logpersistd.enable=true && property:logd.logpersistd=logcatd
    # all exec/services are called with umask(077), so no gain beyond 0700
    mkdir /data/misc/logd 0700 logd log
    start logcatd
```
logcatd与logcat并没有本质上区别，可以通过Android.bp来对比,发现源文件和依赖都是一致的。

```.json
cc_binary {
    name: "logcat",

    defaults: ["logcat_defaults"],
    shared_libs: ["liblogcat"],
    srcs: [
        "logcat_main.cpp",
    ],
}

cc_binary {
    name: "logcatd",

    defaults: ["logcat_defaults"],
    shared_libs: ["liblogcat"],
    srcs: [
        "logcatd_main.cpp",
    ],
}

```

## 2.3 `logcat_main`

## 2.3.1 `android_logat_context`初始化

`logcat_main`的流程异常简洁,如下所示:

```c++
int main(int argc, char** argv, char** envp) {
    //初始化,context一说起就想起上下文
    android_logcat_context ctx = create_android_logcat();
    if (!ctx) return -1;
    //假收到SIGPIPE信号，调用系统调用exit方法终止程序。一般而言建立连接后，假如一端关闭
    //另一端不知道对方关闭仍然写数据，则第一次会受到RST响应，第二次会收到SIGPIPE信号。
    //可重点关注建立连接的两方到底是什么。
    signal(SIGPIPE, exit);
    //该方法是logcat的核心
    int retval = android_logcat_run_command(ctx, -1, -1, argc, argv, envp);
    int ret = android_logcat_destroy(&ctx);
    if (!ret) ret = retval;
    return ret;
```

接下来看下`create_android_logcat`：

```c++
android_logcat_context create_android_logcat() {
    android_logcat_context_internal* context;
    //为android_logcat_context_internal分配内存
    context = (android_logcat_context_internal*)calloc(
        1, sizeof(android_logcat_context_internal));
    if (!context) return nullptr;

    context->fds[0] = -1;
    context->fds[1] = -1;
    context->output_fd = -1;
    context->error_fd = -1;
    //默认最大日志数量为4
    context->maxRotatedLogs = DEFAULT_MAX_ROTATED_LOGS;

    context->argv_hold.clear();
    context->args.clear();
    context->envp_hold.clear();
    context->envs.clear();

    return (android_logcat_context)context;
}
```

针对初始化的内容，反过来看`android_logcat_context_internal`的定义:

```c++
struct android_logcat_context_internal {
    // status
    volatile std::atomic_int retval;  // valid if thread_stopped set
    // Arguments passed in, or copies and storage thereof if a thread.
    int argc;
    char* const* argv;
    char* const* envp;
    //保存logcat中的参数内容
    std::vector<std::string> args;
    std::vector<const char*> argv_hold;
    std::vector<std::string> envs;
    std::vector<const char*> envp_hold;
    int output_fd;  // duplication of fileno(output) (below)
    int error_fd;   // duplication of fileno(error) (below)

    // library
    //这里使用了popen，这应该是对应上文SIGPIPE的处理
    int fds[2];    // From popen call
    //正常输出和错误输出
    FILE* output;  // everything writes to fileno(output), buffer unused
    FILE* error;   // unless error == output.
    pthread_t thr;
    volatile std::atomic_bool stop;  // quick exit flag
    volatile std::atomic_bool thread_stopped;
    bool stderr_null;    // shell "2>/dev/null"
    bool stderr_stdout;  // shell "2>&1"

    // global variables
    AndroidLogFormat* logformat;
    const char* outputFileName;
    // 0 means "no log rotation"
    size_t logRotateSizeKBytes;
    // 0 means "unbounded"
    size_t maxRotatedLogs;
    size_t outByteCount;
    int printBinary;
    int devCount;  // >1 means multiple
    pcrecpp::RE* regex;
    //对应不同缓冲区
    log_device_t* devices;
    EventTagMap* eventTagMap;
    // 0 means "infinite"
    size_t maxCount;
    size_t printCount;

    bool printItAnyways;
    bool debug;
    bool hasOpenedEventTagMap;
};
```

### 2.3.2 `android_logcat_run_command`

```c++
int android_logcat_run_command(android_logcat_context ctx,
                               int output, int error,
                               int argc, char* const* argv,
                               char* const* envp) {
    android_logcat_context_internal* context = ctx;

    context->output_fd = output;
    context->error_fd = error;
    context->argc = argc;
    context->argv = argv;
    context->envp = envp;
    context->stop = false;
    context->thread_stopped = false;
    return __logcat(context);
}
```

logcat如果带上了`-b`参数可以指定缓冲区类型,对于缓冲区的处理如下：

```c++
   //假如context的devices链表头为空，则会将main,system,crash加入
    if (!context->devices) {
        dev = context->devices = new log_device_t("main", false);
        context->devCount = 1;
        if (android_name_to_log_id("system") == LOG_ID_SYSTEM) {
            dev = dev->next = new log_device_t("system", false);
            context->devCount++;
        }
        if (android_name_to_log_id("crash") == LOG_ID_CRASH) {
            dev = dev->next = new log_device_t("crash", false);
            context->devCount++;
        }
    }
    ...
    case 'b': {
    std::unique_ptr<char, void (*)(void*)> buffers(
                    strdup(optctx.optarg), free);
                char* arg = buffers.get();
                unsigned idMask = 0;
                char* sv = nullptr;  // protect against -ENOMEM above
                while (!!(arg = strtok_r(arg, delimiters, &sv))) {
                    if (!strcmp(arg, "default")) {
                        idMask |= (1 << LOG_ID_MAIN) | (1 << LOG_ID_SYSTEM) |
                                  (1 << LOG_ID_CASH);
                    } else if (!strcmp(arg, "all")) {
                        //-b all即指定所有的缓冲区
                        allSelected = true;
                        //即所有位置置为1,推断每一位代表不同的缓冲区
                        idMask = (unsigned)-1;
                    } else {
                        log_id_t log_id = android_name_to_log_id(arg);
                        const char* name = android_log_id_to_name(log_id);

                        if (!!strcmp(name, arg)) {
                            logcat_panic(context, HELP_TRUE,
                                         "unknown buffer %s\n", arg);
                            goto exit;
                        }
                        if (log_id == LOG_ID_SECURITY) allSelected = false;
                        //不同的缓冲区进行置位
                        idMask |= (1 << log_id);
                    }
                    arg = nullptr;
                }
                //检查-b后的参数是否合理，即在LOG_ID_MIN到LOG_ID_MAX之间
                for (int i = LOG_ID_MIN; i < LOG_ID_MAX; ++i) {
                    const char* name = android_log_id_to_name((log_id_t)i);
                    log_id_t log_id = android_name_to_log_id(name);

                    if (log_id != (log_id_t)i) continue;
                    if (!(idMask & (1 << i))) continue;

                    bool found = false;
                    for (dev = context->devices; dev; dev = dev->next) {
                        if (!strcmp(name, dev->device)) {
                            found = true;
                            break;
                        }
                        if (!dev->next) break;
                    }
                    if (found) continue;

                    bool binary = !strcmp(name, "events") ||
                                  !strcmp(name, "security") ||
                                  !strcmp(name, "stats");
                    log_device_t* d = new log_device_t(name, binary);

                    if (dev) {
                        dev->next = d;
                        dev = d;
                    } else {
                        context->devices = dev = d;
                    }
                    context->devCount++;


    }
```


紧接着while的循环中,只要没有指明stop()而且没有定义maxCount.又或者当前打印行数在maxCount之内，就会循环调用processBuffer。其中maxCount可以在logcat时指定`-m`,指定打印的行数。

```c++
while (!context->stop &&
       (!context->maxCount || (context->printCount < context->maxCount))) {
```


```c++
while (!context->stop &&
           (!context->maxCount || (context->printCount < context->maxCount))) {
        struct log_msg log_msg;
        //调用了liblog的接口android_logger_list_read读取log_msg
        int ret = android_logger_list_read(logger_list, &log_msg);
        if (!ret) {
            logcat_panic(context, HELP_FALSE, "read: unexpected EOF!\n");
            break;
        }

        if (ret < 0) {
            if (ret == -EAGAIN) break;

            if (ret == -EIO) {
                logcat_panic(context, HELP_FALSE, "read: unexpected EOF!\n");
                break;
            }
            if (ret == -EINVAL) {
                logcat_panic(context, HELP_FALSE, "read: unexpected length.\n");
                break;
            }
            logcat_panic(context, HELP_FALSE, "logcat read failure\n");
            break;
        }

        log_device_t* d;
        for (d = context->devices; d; d = d->next) {
            if (android_name_to_log_id(d->device) == log_msg.id()) break;
        }
        if (!d) {
            context->devCount = 2; // set to Multiple
            d = &unexpected;
            d->binary = log_msg.id() == LOG_ID_EVENTS;
        }

        if (dev != d) {
            dev = d;
            maybePrintStart(context, dev, printDividers);
            if (context->stop) break;
        }
        if (context->printBinary) {
            printBinary(context, &log_msg);
        } else {
            //输入参数log_msg
            processBuffer(context, dev, &log_msg);
        }

```

这里暂且先不深入看`log_msg`,先看processBuffer是如何处理：

```c++
static void processBuffer(android_logcat_context_internal* context,
                          log_device_t* dev, struct log_msg* buf) {
    int bytesWritten = 0;
    int err;
    AndroidLogEntry entry;
    char binaryMsgBuf[1024];
    //打印二进制内容
    if (dev->binary) {
        if (!context->eventTagMap && !context->hasOpenedEventTagMap) {
            context->eventTagMap = android_openEventTagMap(nullptr);
            context->hasOpenedEventTagMap = true;
        }
        err = android_log_processBinaryLogBuffer(
            &buf->entry_v1, &entry, context->eventTagMap, binaryMsgBuf,
            sizeof(binaryMsgBuf));
        // printf(">>> pri=%d len=%d msg='%s'\n",
        //    entry.priority, entry.messageLen, entry.message);
    } else {
        //处理buf的entry_v1字段，将其转化为entry
        err = android_log_processLogBuffer(&buf->entry_v1, &entry);
    }
    if ((err < 0) && !context->debug) return;

    if (android_log_shouldPrintLine(
            context->logformat, std::string(entry.tag, entry.tagLen).c_str(),
            entry.priority)) {
        bool match = regexOk(context, entry);

        context->printCount += match;
        if (match || context->printItAnyways) {
            //打印entry内容
            bytesWritten = android_log_printLogLine(context->logformat,
                                                    context->output_fd, &entry);

            if (bytesWritten < 0) {
                logcat_panic(context, HELP_FALSE, "output error");
                return;
            }
        }
    }

    context->outByteCount += bytesWritten;
    //如果日志超过了大小，则进行日志循环移动
    if (context->logRotateSizeKBytes > 0 &&
        (context->outByteCount / 1024) >= context->logRotateSizeKBytes) {
        rotateLogs(context);
    }
```

其中`android_log_processLogBuffer`的作用是将`logger_entry`中的字段，如时间(sec,nsec),uid,pid等直接赋值给AndroidLogEntry类型的entry对象中。并将msg经过解释后，解释出priority,tag以及message也保存到entry中。后续调用`android_log_printLogLine`就读取entry内容，并按行进行输出。

```c++
LIBLOG_ABI_PUBLIC int android_log_printLogLine(AndroidLogFormat* p_format,
                                               int fd,
                                               const AndroidLogEntry* entry) {
  int ret;
  char defaultBuffer[512];
  char* outBuffer = NULL;
  size_t totalLen;
  //以一定格式对entry内容进行整理，最后输出为outBuffer,格式是通过-v进行选择的
  outBuffer = android_log_formatLogLine(
      p_format, defaultBuffer, sizeof(defaultBuffer), entry, &totalLen);

  if (!outBuffer) return -1;

  do {
    //输出到文本或终端
    ret = write(fd, outBuffer, totalLen);
  } while (ret < 0 && errno == EINTR);

  if (ret < 0) {
    fprintf(stderr, "+++ LOG: write failed (errno=%d)\n", errno);
    ret = 0;
    goto done;
  }

  if (((size_t)ret) < totalLen) {
    fprintf(stderr, "+++ LOG: write partial (%d of %d)\n", ret, (int)totalLen);
    goto done;
  }

done:
  if (outBuffer != defaultBuffer) {
    free(outBuffer);
  }

  return ret;
}
```

至此，可以比较清晰看出，当不同的模块或应用进行写日志操作时，通过socket写如到logd中，当调用logcat时，可以根据时间和缓冲区的类型，一行一行的将保存的日志内容读取出来，并重新输出。那剩下最后一个问题，就是logcat是如何读取到logd里面的内容，这需要重新回到`log_msg`看其是如何被读取的。

### 2.3.3 `log_msg`读取流程

1.初始化`logger_list`

`logger_list`的定义我并没有找到，但是其形式与`android_log_logger_list`应该一致，因为在初始化流程中有这样的操作:

```c++
LIBLOG_ABI_PUBLIC struct logger_list* android_logger_list_alloc_time(
    int mode, log_time start, pid_t pid) {
struct android_log_logger_list* logger_list;
logger_list = calloc(1, sizeof(*logger_list));
...
}
```

`logger_list`的初始化方式有两种，包括

```c++
if (tail_time != log_time::EPOCH) {
    logger_list = android_logger_list_alloc_time(mode, tail_time, pid);
} else {
    logger_list = android_logger_list_alloc(mode, tail_lines, pid);
}
```

其中第一种方式以`tail_time`作为参数，另一种以`tail_lines`为参数.

我们知道logcat如果以`-t`或者`-T`为参数时，可以跟时间格式，其中`-t`表示非阻塞,即等同于增加了`-d`选项，在日志打印到最新时，会立刻退出。而`tail_time`会在此时被赋值。可以先看logcat关于该选项的处理:


```c++
case 't':
        got_t = true;
        //通过标志位决定日志为只读且非阻塞
        mode |= ANDROID_LOG_RDONLY | ANDROID_LOG_NONBLOCK;
    // FALLTHRU
    case 'T':
        //判断optarg参数是否为数字组成，指明数字为打印最近行数，否则为指定时间
        if (strspn(optarg, "0123456789") != strlen(optarg)) {//打印最近时间
            //解析时间,形式为"%m-%d %H:%M:%S.%q"或者"%Y-%m-%d %H:%M:%S.%q"
            char* cp = parseTime(tail_time, optarg);
            if (!cp) {
                logcat_panic(context, HELP_FALSE, "-%c \"%s\" not in time format\n", c,
                             optarg);
                goto exit;
            }
            if (*cp) {
                char ch = *cp;
                *cp = '\0';
                if (context->error) {
                    fprintf(context->error, "WARNING: -%c \"%s\"\"%c%s\" time truncated\n",
                            c, optarg, ch, cp + 1);
                }
                *cp = ch;//防止野指针？
            }
        } else {//打印最近行数
            //获取`tail_lines`的值
            if (!getSizeTArg(optarg, &tail_lines, 1)) {
                if (context->error) {
                    fprintf(context->error, "WARNING: -%c %s invalid, setting to 1\n", c,
                            optarg);
                }
                tail_lines = 1;
            }
        }
        break;
```

以时间初始化：

```c++
LIBLOG_ABI_PUBLIC struct logger_list* android_logger_list_alloc_time(
    int mode, log_time start, pid_t pid) {
  struct android_log_logger_list* logger_list;

  logger_list = calloc(1, sizeof(*logger_list));
  if (!logger_list) {
    return NULL;
  }

  list_init(&logger_list->logger);
  list_init(&logger_list->transport);
  logger_list->mode = mode;
  logger_list->start = start;
  logger_list->pid = pid;

  logger_list_wrlock();
  list_add_tail(&__android_log_readers, &logger_list->node);
  logger_list_unlock();

  return (struct logger_list*)logger_list;
}
```

以行数初始化：
```c++
LIBLOG_ABI_PUBLIC struct logger_list* android_logger_list_alloc(
    int mode, unsigned int tail, pid_t pid) {
  struct android_log_logger_list* logger_list;

  logger_list = calloc(1, sizeof(*logger_list));
  if (!logger_list) {
    return NULL;
  }

  list_init(&logger_list->logger);
  list_init(&logger_list->transport);
  logger_list->mode = mode;
  logger_list->tail = tail;
  logger_list->pid = pid;

  logger_list_wrlock();
  list_add_tail(&__android_log_readers, &logger_list->node);
  logger_list_unlock();

  return (struct logger_list*)logger_list;
}
```

两种形式都十分相似，只是根据时间格式打印的，会对start进行赋值，而对行数会对tail进行赋值，而`__android_log_readers`是是一个链表头:

```c++
LIBLOG_HIDDEN struct listnode __android_log_readers = { &__android_log_readers,
                                                        &__android_log_readers };
```



2.`android_logger_open`

```c++
while (dev) {
    dev->logger_list = logger_list;
    dev->logger = android_logger_open(logger_list,
                                      android_name_to_log_id(dev->device));
    ...
```

由于开始时初始化了dev设备，所以将会进入到循环中并调用`android_logger_open`方法:
```c++
LIBLOG_ABI_PUBLIC struct logger* android_logger_open(
    struct logger_list* logger_list, log_id_t logId) {
  struct android_log_logger_list* logger_list_internal =
      (struct android_log_logger_list*)logger_list;
  struct android_log_logger* logger;

  if (!logger_list_internal || (logId >= LOG_ID_MAX)) {
    goto err;
  }
  //从logger_list_internal链表中寻找logId相同的logger，如果有，则直接返回该logger
  logger_for_each(logger, logger_list_internal) {
    if (logger->logId == logId) {
      goto ok;
    }
  }
  //如果logger_list_internal不存在该logger，则加入到链表中
  logger = calloc(1, sizeof(*logger));
  if (!logger) {
    goto err;
  }

  logger->logId = logId;
  list_add_tail(&logger_list_internal->logger, &logger->node);
  logger->parent = logger_list_internal;

  /* Reset known transports to re-evaluate, we just added one */
  while (!list_empty(&logger_list_internal->transport)) {
    struct listnode* node = list_head(&logger_list_internal->transport);
    struct android_log_transport_context* transp =
        node_to_item(node, struct android_log_transport_context, node);

    list_remove(&transp->node);
    free(transp);
  }
  goto ok;

err:
  logger = NULL;
ok:
  return (struct logger*)logger;
}

```

3.`android_logger_list_read`

`android_logger_list_read`的实现涉及liblog,这一部分的研究准备放在下一篇对liblog的学习当中阐述。`android_logger_list_read`会调用到如下流程:

```c++
LIBLOG_ABI_PUBLIC int android_logger_list_read(struct logger_list* logger_list,
    struct log_msg* log_msg) {
  struct android_log_transport_context* transp;
  struct android_log_logger_list* logger_list_internal =
      (struct android_log_logger_list*)logger_list;

  int ret = init_transport_context(logger_list_internal);
  if (ret < 0) {
    return ret;
  }

  /* at least one transport */
  transp = node_to_item(logger_list_internal->transport.next,
                        struct android_log_transport_context, node);

   if (transp->node.next != &logger_list_internal->transport) {
   ...
   }
   return android_transport_read(logger_list_internal, transp, log_msg);
}
```

回想起Log写日志流程，也是涉及到transport的write方法，看起来像是粒度更小的读取方式，后续在liblog中再仔细研究.

```c++
static int android_transport_read(struct android_log_logger_list* logger_list,
                                  struct android_log_transport_context* transp,
                                  struct log_msg* log_msg) {
  //transport->read实质上调用到liblog的logd_read方法
  int ret = (*transp->transport->read)(logger_list, transp, log_msg);

  if (ret > (int)sizeof(*log_msg)) {
    ret = sizeof(*log_msg);
  }
  ...
  return ret;

```

随后该方法会调用到`logdRead`的实现，而logdRead会首先会调用logdOpen打开socket节点：

```c++
static int logdOpen(struct android_log_logger_list* logger_list,
                    struct android_log_transport_context* transp) {
    int e, ret, remaining, sock;
    //假如transp已经保存了sock,则直接返回
    sock = atomic_load(&transp->context.sock);
    if (sock > 0) {
       return sock;
    }

     sock = socket_local_client("logdr", ANDROID_SOCKET_NAMESPACE_RESERVED,
        SOCK_SEQPACKET);
    ...
    //此后，会将一些信息发送给logd，比如是否阻塞，是否是打印最近行，是否指定时间打印等
    ret = write(sock, buffer, cp - buffer);
    ...
    //最后将打开的socket保存到transp->context.sock中，下次就可以直接使用了
    ret = atomic_exchange(&transp->context.sock, sock);
    if ((ret > 0) && (ret != sock)) {
        close(ret);
    }
```

从logdOpen可以看到，logcat通过/dev/socket/logdr这个socket进行通信，并通过logdRead接收消息，至此logcat从读取消息，到输出的流程简单分析完毕。

```c++
static int logdRead(struct android_log_logger_list* logger_list,
                    struct android_log_transport_context* transp,
                    struct log_msg* log_msg) {
     int ret, e;
    //logdOpen后，socket信息都保存在了transp结构体中
    ret = logdOpen(logger_list, transp);
    if (ret < 0) {
        return ret;
    }
    memset(log_msg, 0, sizeof(*log_msg));
    //通过socket接收log_msg,LOGGER_ENTRY_MAX_LEN为5*1024(5K)
    ret = recv(ret, log_msg, LOGGER_ENTRY_MAX_LEN, 0);
    ...
    return ret;
```

从Framework写日志到liblog，再到logcat从liblog中读取日志，这里的流程都是简单的追踪了一遍，其中涉及的liblog的分析，安排在后续的学习计划当中。所接触的linux3.4(对应Kitkat)，当时的日志存储在内核空间中，到最近的版本，liblog实现放在了用户空间中，所以导致liblog的实现和驱动实现很类似，也不易看懂，后续将仔细研究下liblog的实现，争取将前两节的分析难理解的细节融会贯通。
