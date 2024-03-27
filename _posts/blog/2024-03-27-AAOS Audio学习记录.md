---
author: Bill
catalog: true
date: '2024-03-27'
guitartab: false
header-img: img/bill/header-posts/2024-01-24-header.png
hide: false
layout: post
life: false
stickie: false
summary: '"AAOS Audio学习记录"'
tags: []
title: AAOS Audio学习记录
---
# 1. 背景

默认的Android Audio在Framework层进行混音后输出到音频设备，而在车载场景，往往需要将不同类型的声音，如系统音，导航音，音乐等通过配置在不同设备中分别输出，这个需求与以往Android Audio的实现有所区别，为了研究AAOS是如何实现这个功能，又是如何对接到AudioFlinger/AudioPolicyService，现对AAOS Audio进行通路学习。

官网的框架图如下所示：

![image](https://source.android.com/static/docs/automotive/images/14-audio-01.png?hl=zh-cn)

从上图的框架，将从CarAudioManager，CarAudioService，AudioFlinger，AudioControl HAL这四个方面着手分析。

# 2. CarAudioManager

CarAudioManager的代码位于`packages/services/Car/car-lib/src/android/car/media/`，官网的接口说明链接为[https://developer.android.com/reference/android/car/media/CarAudioManager](https://developer.android.com/reference/android/car/media/CarAudioManager).

CarAudioManager可以理解为专门用于车载的音频APIS，如果在config.xml打开了属性audioUseDynamicRouting，那么就开启了动态路由(dynamic routing)的开关, 即所有的音频设备都被划分成为以“Zone”为单位，其中至少有一个primary zone，且音频设备也会根据“Group”组为单位进行音量的控制。如果动态路由关闭，Audio就会根据AudioAttribue去设置音频设备了。

## 2.1 API介绍

内部类: CarAudioManager.CarVolumeCallback

这个回调类专门用于接收音量变化的事件，其中包括接口：

- onGroupMuteChanged: 当Group静音状态发生变化
- onGroupVolumeChanged: 当Group的音量大小发生变化
- onMasterMuteChanged: 当全局的静音状态发生变化

原理分析：
回调类用于跨进程的通信，应用首先会在应用层创建一个回调对象，实现上述接口来监听静音，音量变化。并通过carAudioManager的registerCarVolumeCallback将回调方法注册进去。CarAudioManager本身会定义一个CopyOnWriteArrayList类型的mCarVolumeCallback对象，用于管理应用传入的回调对象，即registerCarVolumeCallback的时候add进去，unregisterCarVolumeCallback时remove。（CopyOnWriterArrayList是Java的一个提供线程安全的ArrayList，用途是在多线程的环境下提供高效读操作的方式，其特点是在读时可以随意读，写的时候会先创建一个副本，并在副本上修改，完成后再更新为副本对象，因此写操作开销大。)carAudioManager的registerCarVolumeCallback除了将应用传入的回调对象进行本地保存，还会将一个ICarVolumeCallback的Stub实现传给CarAudioService中。当CarAudioService得知发生了音量的变化时，便可以通过Binder跨进程通信到CarAudioManager，并通过发送Handler发送消息到应用的Looper线程，最终通过mCarVolumeCallback实现应用回调方法的调用。

接口:

- isAudioFeatureEnabled: 这个接口用于判断audio特性是否支持，通过CarAudioService获取。
- registerCarVolumeCallback: 注册音量回调方法。
- unregisterCarVolumeCallback: 注销音量回调。


总结：CarAudioManager为应用提供了音量回调的接口，并且能够查询Audio的特性。从实现上来看，CarAudioManager除了有AudioManager的属性，还直接和CarAudioService进行交互，包括回调的调用，设置和获取Group的音量等，最终都需要调用CarAudioService，可在后续章节继续分析。从CarAudioManager的设计而言，其继承了CarManagerBase。基类的特点是都维护了一个Car的对象，并且提供了一些公共的处理异常，dump的接口。CarAudioManager可以通过如下形式进行获取：

```java
mCarAudioManager = (CarAudioManager) car.getCarManager(Car.AUDIO_SERVICE); 
```






