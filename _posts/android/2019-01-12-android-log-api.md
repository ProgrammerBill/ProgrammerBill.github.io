---
layout:     post
title:      "Android Log写日志流程分析"
summary:    '"Android log"'
date:       2019-01-12 13:52:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-01-12.jpg"
catalog: true
tags:
    - android
---


<!-- vim-markdown-toc GFM -->

* [1. 前言](#1-前言)
* [2.Java日志记录接口](#2java日志记录接口)
* [3. C++日志记录接口](#3-c日志记录接口)
* [4. liblog](#4-liblog)

<!-- vim-markdown-toc -->

# 1. 前言

平时在开发过程中，少不了进行调试打印，Android在为开发者提供了Java，C++的日志接口，开发者通过logcat工具就可以通过串口或者ADB获取应用或这Framework的工作状态。其中Logd负责承上启下，自上与用添加的日志语句向呼应，自下可以在logcat运行时，将日志显示出来。本章节打算以三个方面进行分析，以弄清楚Log的运行机制。本文首先以用户添加日志的角度去分析。

# 2.Java日志记录接口

Framework提供了3种Java接口写日志,分别是android.util.Log,android.util.Slog,android.util.Event.Log，它们写入的日志类型是main，system以及event，以其中的android.util.Log为例，其打印等级包括

- verbose
- debug
- info
- warning
- error
- assert

以常用的debug等级为例，其实现如下:

```
//frameworks/base/core/java/android/util/Log.java
public static int d(String tag, String msg) {
    return println_native(LOG_ID_MAIN, DEBUG, tag, msg);
}

```

一般在开发流程中添加语句就可以以TAG,Message的方式增加日志，而视日志的严重程度来挑选打印等级。


Java的打印语句只是提供了接口，其实质依赖于Native层的实现，可以猜想，在C++中日志语句最终与Java也是殊途同归,先看看JNI的实现：

```
//frameworks/base/core/java/android/util/Log.java
/** @hide */ public static native int println_native(int bufID,
         int priority, String tag, String msg);
```

```
//frameworks/base/core/jni/android_util_Log.cpp
static const JNINativeMethod gMethods[] = {
    /* name, signature, funcPtr */
    //println_native对应函数android_util_Log_println_native 
    { "println_native",  "(IILjava/lang/String;Ljava/lang/String;)I", (void*) android_util_Log_println_native },
    ...
};
//注册Jni方法
int register_android_util_Log(JNIEnv* env)
{
    jclass clazz = FindClassOrDie(env, "android/util/Log");
    levels.verbose = env->GetStaticIntField(clazz, GetStaticFieldIDOrDie(env, clazz, "VERBOSE", "I"));
    levels.debug = env->GetStaticIntField(clazz, GetStaticFieldIDOrDie(env, clazz, "DEBUG", "I"));
    levels.info = env->GetStaticIntField(clazz, GetStaticFieldIDOrDie(env, clazz, "INFO", "I"));
    levels.warn = env->GetStaticIntField(clazz, GetStaticFieldIDOrDie(env, clazz, "WARN", "I"));
    levels.error = env->GetStaticIntField(clazz, GetStaticFieldIDOrDie(env, clazz, "ERROR", "I"));
    levels.assert = env->GetStaticIntField(clazz, GetStaticFieldIDOrDie(env, clazz, "ASSERT", "I"));
    return RegisterMethodsOrDie(env, "android/util/Log", gMethods, NELEM(gMethods));
}
```

上述的方法在调用AndroidRuntime::start的时候会被调用并进行注册,所以Java程序在启动时，都会注册日志的方法。


```
//frameworks/base/core/jni/android_util_Log.cpp
static jint android_util_Log_println_native(JNIEnv* env, jobject clazz,
        jint bufID, jint priority, jstring tagObj, jstring msgObj)
{
    const char* tag = NULL;
    const char* msg = NULL;

    if (msgObj == NULL) {
        jniThrowNullPointerException(env, "println needs a message");
        return -1;
    }

    if (bufID < 0 || bufID >= LOG_ID_MAX) {
        jniThrowNullPointerException(env, "bad bufID");
        return -1;
    }

    if (tagObj != NULL)
        tag = env->GetStringUTFChars(tagObj, NULL);
    msg = env->GetStringUTFChars(msgObj, NULL);
    
    //调用__android_log_buf_write写入日志
    int res = __android_log_buf_write(bufID, (android_LogPriority)priority, tag, msg);

    if (tag != NULL)
        env->ReleaseStringUTFChars(tagObj, tag);
    env->ReleaseStringUTFChars(msgObj, msg);

    return res;
}
```

从Jni过来，调用到liblog库的接口，其中可见日志保存了prio，tag，msg三个元素,这里暂时不往下看，转而看C++的实现。

# 3. C++日志记录接口

与Java日志相似，C++的log的实现在如下文件：

- system/core/include/log/log_main.h
- system/core/include/log/log_system.h
- system/core/include/log/log_radio.h

以`log_main.h`为例，打印Error日志的实现如下：

```
//system/core/include/log/log_main.h
#ifndef ALOGE
#define ALOGE(...) ((void)ALOG(LOG_ERROR, LOG_TAG, __VA_ARGS__))
#endif
```

首先在Native层文件需要定义`LOG_TAG`,打印示例如下：

```
ALOGE("This is a example: %s", message);
```

往下追踪可看ALOG的实现:

```
/*
 * Basic log message macro.
 *
 * Example:
 *  ALOG(LOG_WARN, NULL, "Failed with error %d", errno);
 *
 * The second argument may be NULL or "" to indicate the "global" tag.
 */
#ifndef ALOG
#define ALOG(priority, tag, ...) LOG_PRI(ANDROID_##priority, tag, __VA_ARGS__)
#endif


#ifndef LOG_PRI
#define LOG_PRI(priority, tag, ...) android_printLog(priority, tag, __VA_ARGS__)
#endif

#define android_printLog(prio, tag, ...) \
  __android_log_print(prio, tag, __VA_ARGS__)
```

至此，可以看出C++的打印最终调用了`__android_log_print(prio, tag, __VA_ARGS__)`,该方法和Java追踪到的`__android_log_buf_write`有关联，该实现均在liblog模块中。



# 4. liblog


首先列出Java的实现，可见prio,tag,msg最终均放在了一个叫iovec的数据结构当中

```
//system/core/liblog/logger_write.c
LIBLOG_ABI_PUBLIC int __android_log_buf_write(int bufID, int prio,
        const char* tag, const char* msg) {
  struct iovec vec[3];
  char tmp_tag[32];
  ...
  vec[0].iov_base = (unsigned char*)&prio;
  vec[0].iov_len = 1;
  vec[1].iov_base = (void*)tag;
  vec[1].iov_len = strlen(tag) + 1;
  vec[2].iov_base = (void*)msg;
  vec[2].iov_len = strlen(msg) + 1;
    
  return write_to_log(bufID, vec, 3);
}
```

C++的实现也类似:

```
LIBLOG_ABI_PUBLIC int __android_log_print(int prio, const char* tag,
                                          const char* fmt, ...) {
  va_list ap;
  char buf[LOG_BUF_SIZE];

  va_start(ap, fmt);
  vsnprintf(buf, LOG_BUF_SIZE, fmt, ap);
  va_end(ap);

  return __android_log_write(prio, tag, buf);
}

LIBLOG_ABI_PUBLIC int __android_log_write(int prio, const char* tag,
                                          const char* msg) {
 //C++的实现最终也是调用到相同的接口
  return __android_log_buf_write(LOG_ID_MAIN, prio, tag, msg);
}
```

回过头来看iovec的定义，发现其就包括了一个地址以及长度，十分简洁。`__android_log_buf_write`就将prio,tag,message分别保存在长度为3的iovec结构体中。

```
//system/core/liblog/include/log/uio.h
struct iovec {
  void* iov_base;
  size_t iov_len;
};
```

再继续看`write_to_log`,`write_to_log`定义为函数指针，在初始化阶段时指向函数`__write_to_log_init`,后期指向`__write_to_log_daemon`。

```
static int __write_to_log_daemon(log_id_t log_id, struct iovec* vec, size_t nr) {
  struct android_log_transport_write* node;
  ...
  for (len = i = 0; i < nr; ++i) {
    len += vec[i].iov_len;
  }
  if (!len) {
    return -EINVAL;
  }
  ...
  write_transport_for_each(node, &__android_log_transport_write) {
    if (node->logMask & i) {
      ssize_t retval;
      //write调用的是logd_writer的接口logdWrite    
      retval = (*node->write)(log_id, &ts, vec, nr);
      if (ret >= 0) {
        ret = retval;
      }
    }
  }
...
}
```

`android_log_transport_write`类型定义在logd_writer,其文件的命名方式可以看出，该文件定义的时向logd进行写操作的方法，其实现也和驱动十分相似：

```
//system/core/liblog/logd_writer.c
LIBLOG_HIDDEN struct android_log_transport_write logdLoggerWrite = {
  .node = { &logdLoggerWrite.node, &logdLoggerWrite.node },
  .context.sock = -EBADF,
  .name = "logd",
  .available = logdAvailable,
  .open = logdOpen,
  .close = logdClose,
  .write = logdWrite,
};
```

至此其实目的时想了解上层是如何和logd进行交互，从logdOpen可见，最终上层是将信息写到logdw的socket套接口与logd完成通信:

```
static int logdOpen() {
  int i, ret = 0;

  i = atomic_load(&logdLoggerWrite.context.sock);
  if (i < 0) {
    int sock = TEMP_FAILURE_RETRY(
        socket(PF_UNIX, SOCK_DGRAM | SOCK_CLOEXEC | SOCK_NONBLOCK, 0));
    if (sock < 0) {
      ret = -errno;
    } else {
      struct sockaddr_un un;
      memset(&un, 0, sizeof(struct sockaddr_un));
      un.sun_family = AF_UNIX;
      strcpy(un.sun_path, "/dev/socket/logdw");
      //打开"/dev/socket/logdw",这正是logd的socket之一
      if (TEMP_FAILURE_RETRY(connect(sock, (struct sockaddr*)&un,
                                     sizeof(struct sockaddr_un))) < 0) {
        ret = -errno;
        switch (ret) {
          case -ENOTCONN:
          case -ECONNREFUSED:
          case -ENOENT:
            i = atomic_exchange(&logdLoggerWrite.context.sock, ret);
          /* FALLTHRU */
          default:
            break;
        }
        close(sock);
      } else {
        ret = atomic_exchange(&logdLoggerWrite.context.sock, sock);
        if ((ret >= 0) && (ret != sock)) {
          close(ret);
        }
        ret = 0;
      }
    }
  }
  return ret;
}
```

接下来看如何实现写操作:

```
static int logdWrite(log_id_t logId, struct timespec* ts, struct iovec* vec,
                     size_t nr) {
  ssize_t ret;
  int sock;
  static const unsigned headerLength = 1;
  struct iovec newVec[nr + headerLength];
  android_log_header_t header;
  size_t i, payloadSize;
  static atomic_int_fast32_t dropped;
  static atomic_int_fast32_t droppedSecurity;

  sock = atomic_load(&logdLoggerWrite.context.sock);
  if (sock < 0) switch (sock) {
      case -ENOTCONN:
      case -ECONNREFUSED:
      case -ENOENT:
        break;
      default:
        return -EBADF;
    }

  /* logd, after initialization and priv drop */
  if (__android_log_uid() == AID_LOGD) {
    /*
     * ignore log messages we send to ourself (logd).
     * Such log messages are often generated by libraries we depend on
     * which use standard Android logging.
     */
    return 0;
  }

  /*
   *  struct {
   *      // what we provide to socket
   *      android_log_header_t header;
   *      // caller provides
   *      union {
   *          struct {
   *              char     prio;
   *              char     payload[];
   *          } string;
   *          struct {
   *              uint32_t tag
   *              char     payload[];
   *          } binary;
   *      };
   *  };
   */

  header.tid = gettid();
  header.realtime.tv_sec = ts->tv_sec;
  header.realtime.tv_nsec = ts->tv_nsec;

  newVec[0].iov_base = (unsigned char*)&header;
  newVec[0].iov_len = sizeof(header);

  if (sock >= 0) {
    int32_t snapshot =
        atomic_exchange_explicit(&droppedSecurity, 0, memory_order_relaxed);
    if (snapshot) {
      android_log_event_int_t buffer;

      header.id = LOG_ID_SECURITY;
      buffer.header.tag = htole32(LIBLOG_LOG_TAG);
      buffer.payload.type = EVENT_TYPE_INT;
      buffer.payload.data = htole32(snapshot);

      newVec[headerLength].iov_base = &buffer;
      newVec[headerLength].iov_len = sizeof(buffer);

      ret = TEMP_FAILURE_RETRY(writev(sock, newVec, 2));
      if (ret != (ssize_t)(sizeof(header) + sizeof(buffer))) {
        atomic_fetch_add_explicit(&droppedSecurity, snapshot,
                                  memory_order_relaxed);
      }
    }
    snapshot = atomic_exchange_explicit(&dropped, 0, memory_order_relaxed);
    if (snapshot &&
        __android_log_is_loggable_len(ANDROID_LOG_INFO, "liblog",
                                      strlen("liblog"), ANDROID_LOG_VERBOSE)) {
      android_log_event_int_t buffer;

      header.id = LOG_ID_EVENTS;
      buffer.header.tag = htole32(LIBLOG_LOG_TAG);
      buffer.payload.type = EVENT_TYPE_INT;
      buffer.payload.data = htole32(snapshot);

      newVec[headerLength].iov_base = &buffer;
      newVec[headerLength].iov_len = sizeof(buffer);

      ret = TEMP_FAILURE_RETRY(writev(sock, newVec, 2));
      if (ret != (ssize_t)(sizeof(header) + sizeof(buffer))) {
        atomic_fetch_add_explicit(&dropped, snapshot, memory_order_relaxed);
      }
    }
  }

  header.id = logId;

  //将消息内容拷贝到newVec中
  for (payloadSize = 0, i = headerLength; i < nr + headerLength; i++) {
    newVec[i].iov_base = vec[i - headerLength].iov_base;
    payloadSize += newVec[i].iov_len = vec[i - headerLength].iov_len;

    if (payloadSize > LOGGER_ENTRY_MAX_PAYLOAD) {
      newVec[i].iov_len -= payloadSize - LOGGER_ENTRY_MAX_PAYLOAD;
      if (newVec[i].iov_len) {
        ++i;
      }
      break;
    }
  }

  /*
   * The write below could be lost, but will never block.
   *
   * ENOTCONN occurs if logd has died.
   * ENOENT occurs if logd is not running and socket is missing.
   * ECONNREFUSED occurs if we can not reconnect to logd.
   * EAGAIN occurs if logd is overloaded.
   */
  if (sock < 0) {
    ret = sock;
  } else {
    //调用writev向socket写信息
    ret = TEMP_FAILURE_RETRY(writev(sock, newVec, i));
    if (ret < 0) {
      ret = -errno;
    }
  }
  switch (ret) {
    case -ENOTCONN:
    case -ECONNREFUSED:
    case -ENOENT:
      if (__android_log_trylock()) {
        return ret; /* in a signal handler? try again when less stressed */
      }
      __logdClose(ret);
      ret = logdOpen();
      __android_log_unlock();

      if (ret < 0) {
        return ret;
      }

      ret = TEMP_FAILURE_RETRY(
          writev(atomic_load(&logdLoggerWrite.context.sock), newVec, i));
      if (ret < 0) {
        ret = -errno;
      }
    /* FALLTHRU */
    default:
      break;
  }

  if (ret > (ssize_t)sizeof(header)) {
    ret -= sizeof(header);
  } else if (ret == -EAGAIN) {
    atomic_fetch_add_explicit(&dropped, 1, memory_order_relaxed);
    if (logId == LOG_ID_SECURITY) {
      atomic_fetch_add_explicit(&droppedSecurity, 1, memory_order_relaxed);
    }
  }

  return ret;
}
```

至此，Android向Logd写数据的流程暂分析结束，接下来从Logcat,Logd两方面分析。






