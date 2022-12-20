---
layout:     post
title:      "Android开发平台区分"
summary:    '"Android platform-distinguish"'
date:       2018-10-31 14:04:00
author:     "Bill"
header-img: "img/bill/header-posts/2018-10-16.jpg"
catalog: true
tags:
    - android
---


<!-- vim-markdown-toc GFM -->

* [1. 背景](#1-背景)
* [2. FrameWork层平台区分](#2-framework层平台区分)
	* [2.1 通过系统属性区分](#21-通过系统属性区分)
	* [2.2 通过自定义方法区分](#22-通过自定义方法区分)
		* [2.2.1 增加宏定义](#221-增加宏定义)
		* [2.2.2 Native层实现](#222-native层实现)
* [3. Native层平台区分](#3-native层平台区分)
* [4. FrameWork资源文件区分](#4-framework资源文件区分)

<!-- vim-markdown-toc -->

# 1. 背景

在编译Android Rom时，由于需要在同一个分支上开发多个产品，所以需要在代码中根据平台来区分，以免混淆。

在编译时，通过选择lunch来选择特定平台，如:

```
$lunch

1. CHIP_A_BUSINESS_1_eng
2. CHIP_A_BUSINESS_1_user
3. CHIP_A_BUSINESS_2_eng
4. CHIP_A_BUSINESS_2_user
5. CHIP_B_BUSINESS_1_eng
...
```

上述展示了`CHIP_A`平台中，根据业务分成了`CHIP_A_BUSINESS_1,CHIP_A_BUISNESS_2`两类选择，此时的方案结构设计应当如下所示:

![](/img/bill/in-posts/2018-10-31/1.png)


此时可以将对应的芯片平台在`CHIP_A_common`中的BoardConfigCommon.mk文件中定义变量:

```
CHIP_PLATFORM := CHIP_A 
```

表明该方案是使用了`CHIP_A`这个芯片平台。当获取该变量时，便可以区分是`CHIP_A`还是`CHIP_B`了。

同理，可在方案目录中如`CHIP_A_BUSINESS_1`中BoardConfig.mk中再定义一个变量，表明为方案1

```
BUSINESS_PLATFORM := BUSINESS_1
```

# 2. FrameWork层平台区分

## 2.1 通过系统属性区分

通过获取系统属性`ro.build.product`,`ro.product.device`,`ro.product.name`均可以获取平台内容，相关的属性在方案mk中必须定义:

```
PRODUCT_BRAND := ....
PRODUCT_NAME := ...
PRODUCT_DEVICE := ...
```

属性的获取可如下:

```
String mProperty = SystemProperties.get("ro.build.product"); 
```

## 2.2 通过自定义方法区分

通过自定义方法即实现一套接口，能够从Java层，Native层获取平台属性，但需要修改以下SDK的内容，包括：

### 2.2.1 增加宏定义

由于选择方案时已加入`XX_CHIP_PLATFORM := A`,　但该变量在代码中不能直接读取，可以通过mk进行如下修改:

```
# build/core/device_config.mk
ifeq (CHIP_A, $(CHIP_PLATFORM))
    LOCAL_CFLAGS += -DCHIP_PLATFORM=0x00
endif
ifeq (CHIP_B, $(CHIP_PLATFORM))
    LOCAL_CFLAGS += -DCHIP_PLATFORM=0x01
endif
```
		
### 2.2.2 Native层实现
		
由于编译时时加入了宏定义，此时使用C/C++开发时，即可以获取到`CHIP_PLATFORM`变量,由此可编译出共享库并提供如下接口:
		
```
extern "C" uint32_t getBoardPlatform()
{

#ifdef xxx_CHIP_PLATFORM
	return xxx_CHIP_PLATFORM;
#else
	return UNKNOWN_PLATFORM;
#endif                                                                                              
}

extern "C" uint32_t getBusinessPlatform()
{
#ifdef xxx_BUSINESS_PLATFORM
	return xxx_BUSINESS_PLATFORM;
#else
	return UNKNOWN_PLATFORM;
#endif
}
```

Java，JNI只需要简单的调用如上方法，即可以分别在Java,Native层进行平台区分了。

# 3. Native层平台区分

除上述方法能在native层进行平台区分外，还可以通过编译宏来进行平台区分，即:

```
#ifdef CHIP_PLATFORM
....
#endif
```

# 4. FrameWork资源文件区分

如有需要替换FrameWork的资源文件，可以通过在方案平台中的overlay机制进行资源覆盖。

