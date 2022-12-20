---
layout:     post
title:      "Scheme V2 App安装报错"
summary:   '"Apk安装问题"'
date:       2019-08-14 16:05:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-08-14.jpg"
catalog: true
tags:
    - default
---



# 1.问题现象

当第三方Apk经过Android.mk后编译进系统后,在预安装过程中会出现如下的错误提示:

```
Failure [INSTALL_PARSE_FAILED_NO_CERTIFICATES: Failed to collect certificates fr
om /data/app/vmdl325607430.tmp/base.apk: META-INF/CERT.SF indicates /data/app/vmdl325607430.tmp/base.apk is signed using APK Signature Scheme v2, but no such
signature was found. Signature stripped?]
```

如果直接进行安装,未经过Android.mk编译的Apk可以安装成功,但是经过Android.mk编译的Apk也同样会出现这样的错误.


# 2.相关知识

APK 签名方案 v2 是一种全文件签名方案，该方案能够发现对 APK 的受保护部分进行的所有更改，从而有助于加快验证速度并增强完整性保证。

使用 APK 签名方案 v2 进行签名时，会在 APK 文件中插入一个 APK 签名分块，该分块位于“ZIP 中央目录”部分之前并紧邻该部分。在“APK 签名分块”内，v2 签名和签名者身份信息会存储在 APK 签名方案 v2 分块中。

![](/img/bill/in-posts/2019-08-14/1.png)


为了保护 APK 内容，APK 包含以下 4 个部分：

- ZIP 条目的内容（从偏移量 0 处开始一直到“APK 签名分块”的起始位置）
- APK 签名分块
- ZIP 中央目录
- ZIP 中央目录结尾

APK 签名方案 v2 负责保护第 1、3、4 部分的完整性，以及第 2 部分包含的“APK 签名方案 v2 分块”中的 signed data 分块的完整性。

第 1、3 和 4 部分的完整性通过其内容的一个或多个摘要来保护，这些摘要存储在 signed data 分块中，而这些分块则通过一个或多个签名来保护。

第 1、3 和 4 部分的摘要采用以下计算方式，类似于两级 Merkle 树。 每个部分都会被拆分成多个大小为 1 MB（220 个字节）的连续块。每个部分的最后一个块可能会短一些。每个块的摘要均通过字节 0xa5 的连接、块的长度（采用小端字节序的 uint32 值，以字节数计）和块的内容进行计算。顶级摘要通过字节 0x5a 的连接、块数（采用小端字节序的 uint32 值）以及块的摘要的连接（按照块在 APK 中显示的顺序）进行计算。摘要以分块方式计算，以便通过并行处理来加快计算速度。

由于第 4 部分（ZIP 中央目录结尾）包含“ZIP 中央目录”的偏移量，因此该部分的保护比较复杂。当“APK 签名分块”的大小发生变化（例如，添加了新签名）时，偏移量也会随之改变。因此，在通过“ZIP 中央目录结尾”计算摘要时，必须将包含“ZIP 中央目录”偏移量的字段视为包含“APK 签名分块”的偏移量。

![](/img/bill/in-posts/2019-08-14/2.png)

详情关于V2签名的可以查看如下链接:

[APK 签名方案 v2](https://source.android.com/security/apksigning/v2)

# 3.问题解决

首先展现下Android.mk的内容:

```
LOCAL_PATH := $(call my-dir)
include $(CLEAR_VARS)

LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_CERTIFICATE := PRESIGNED

LOCAL_MODULE_PATH := [Apk需要放置的目录]

LOCAL_MODULE := [Apk名称]
LOCAL_DEX_PREOPT := true
LOCAL_SRC_FILES := $(LOCAL_MODULE).apk

include $(BUILD_PREBUILT)
```

查阅资料可得,是由于App经过了某些优化或者改动导致破坏了签名,才导致问题的出现.于是着重尝试了`LOCAL_DEX_PREOPT`的设置.但是无论怎么改动,发现生成的Apk的md5值都是不变的(编译eng固件).

![](/img/bill/in-posts/2019-08-14/3.png)

详细可以参考如下链接:
[配置 ART](https://source.android.com/devices/tech/dalvik/configure)

于是转眼认为是编译`BUILD_PREBUILT`时,系统做了一些额外的操作,最后定位到了zipalign进行了优化行为.

```
$(built_module) : $(my_prebuilt_src_file) | $(ZIPALIGN) $(SIGNAPK_JAR)
	$(transform-prebuilt-to-target)
	$(uncompress-shared-libs)
```

将uncompress-shared-libs去掉后,out目录生成的Apk与原本的Apk经过md5对比后完全一样.

于是可以在Android.mk自定义选项,如`LOCAL_NO_ZIPALIGN`,同时修改`build/core/prebuilt_internal.mk`:

```
$(built_module) : $(my_prebuilt_src_file) | $(ZIPALIGN) $(SIGNAPK_JAR)
	$(transform-prebuilt-to-target)
ifneq (true, $(LOCAL_NO_ZIPALIGN)) #当且仅有设置将LOCAL_NO_ZIPALIGN设置为true时,不会运行该步骤
	$(uncompress-shared-libs)
endif
```

