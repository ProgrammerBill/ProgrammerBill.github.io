---
layout:     post
title:      "Android AMS 图解"
summary:    '"Android AMS ActivityManagerservice"'
date:       2019-01-24 14:26:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-01-17.jpg"
catalog: true
tags:
    - android
---


<!-- vim-markdown-toc GFM -->

* [1.前言](#1前言)
* [2. AMS创建Activity流程](#2-ams创建activity流程)
* [3. AMS创建Service流程](#3-ams创建service流程)
* [4. AMS 广播接收流程](#4-ams-广播接收流程)

<!-- vim-markdown-toc -->

# 1.前言

ActivtyManagerService是Android系统的重要服务，它管理着四大组件的Activity，BroadcastReceiver,Services，ContentProvider，本文将以AMS的几个重要流程以图的形式展现，方便日后查问题能快速定位。AMS的代码以Android P进行分析。

# 2. AMS创建Activity流程

![](/img/bill/in-posts/2019-01-24/ams_p.png)

大图链接:
[http://www.cjcbill.com/img/bill/in-posts/2019-01-24/ams_p.png](http://www.cjcbill.com/img/bill/in-posts/2019-01-24/ams_p.png)


# 3. AMS创建Service流程


![](/img/bill/in-posts/2019-01-24/ams_p.png)

大图链接:
[http://www.cjcbill.com/img/bill/in-posts/2019-01-24/ams_p_service.png](http://www.cjcbill.com/img/bill/in-posts/2019-01-24/ams_p_service.png)

# 4. AMS 广播接收流程


![](/img/bill/in-posts/2019-01-24/ams_p_receiver.png)

大图链接:
[http://www.cjcbill.com/img/bill/in-posts/2019-01-24/ams_p_receiver.png](http://www.cjcbill.com/img/bill/in-posts/2019-01-24/ams_p_receiver.png)

