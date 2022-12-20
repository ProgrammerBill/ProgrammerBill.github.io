---
layout:     post
title:      "Android Binder驱动数据结构图解"
summary:    '"Android Binder"'
date:       2019-05-21 18:51:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-05-21.jpg"
catalog: true
tags:
    - android
    - Binder
---


<!-- vim-markdown-toc GFM -->

* [1.背景](#1背景)
* [2. Binder驱动数据结构](#2-binder驱动数据结构)
	* [2.1	`binder_proc`](#21binder_proc)
	* [2.2 `binder_thread`](#22-binder_thread)
	* [2.3 `binder_ref`](#23-binder_ref)
	* [2.4 `binder_node`](#24-binder_node)
	* [2.5 `binder_transaction`](#25-binder_transaction)
	* [2.6 `binder_buffer`](#26-binder_buffer)
	* [2.7 `binder_write_read`](#27-binder_write_read)
	* [2.8 `binder_ref_death`](#28-binder_ref_death)
	* [2.9 `binder_driver_command_protocol`](#29-binder_driver_command_protocol)
	* [2.10 `binder_driver_return_protocol`](#210-binder_driver_return_protocol)
	* [2.11 `binder_ptr_cookie`](#211-binder_ptr_cookie)
	* [2.12 `binder_transaction_data`](#212-binder_transaction_data)
	* [2.13 `flat_binder_object`](#213-flat_binder_object)

<!-- vim-markdown-toc -->


# 1.背景

本文主要希望通过图解的方式梳理清楚Binder驱动的数据结构和基本操作流程,帮助理解Binder通信的本质。首先展示一张
Binder数据结构的合集图:

![](/img/bill/in-posts/2019-05-21/binder_data_structures.png)

[大图链接 `binder_proc`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_data_structures.png)


# 2. Binder驱动数据结构

## 2.1	`binder_proc`

![](/img/bill/in-posts/2019-05-21/binder_proc.png)

[大图链接 `binder_proc`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_proc.png)


## 2.2 `binder_thread`

![](/img/bill/in-posts/2019-05-21/binder_thread.png)

[大图链接 `binder_thread`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_thread.png)

## 2.3 `binder_ref`

![](/img/bill/in-posts/2019-05-21/binder_ref.png)

[大图链接 `binder_ref`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_ref.png)


## 2.4 `binder_node`

![](/img/bill/in-posts/2019-05-21/binder_node.png)

[大图链接 `binder_node`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_node.png)


## 2.5 `binder_transaction`

![](/img/bill/in-posts/2019-05-21/binder_transaction.png)

[大图链接 `binder_transaction`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_transaction.png)


## 2.6 `binder_buffer`

![](/img/bill/in-posts/2019-05-21/binder_buffer.png)

[大图链接 `binder_buffer`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_buffer.png)


## 2.7 `binder_write_read`

![](/img/bill/in-posts/2019-05-21/binder_write_read.png)

[大图链接 `binder_write_read`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_write_read.png)

## 2.8 `binder_ref_death`

![](/img/bill/in-posts/2019-05-21/binder_ref_death.png)

[大图链接 `binder_ref_death`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_ref_death.png)

## 2.9 `binder_driver_command_protocol`

![](/img/bill/in-posts/2019-05-21/binder_driver_command_protocol.png)

[大图链接 `binder_driver_command_protocol`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_driver_command_protocol.png)

## 2.10 `binder_driver_return_protocol`

![](/img/bill/in-posts/2019-05-21/binder_driver_return_protocol.png)

[大图链接 `binder_driver_return_protocol`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_driver_return_protocol.png)


## 2.11 `binder_ptr_cookie`

![](/img/bill/in-posts/2019-05-21/binder_ptr_cookie.png)

[大图链接 `binder_ptr_cookie`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_ptr_cookie.png)

## 2.12 `binder_transaction_data`

![](/img/bill/in-posts/2019-05-21/binder_transaction_data.png)

[大图链接 `binder_transaction_data`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/binder_transaction_data.png)


## 2.13 `flat_binder_object`

![](/img/bill/in-posts/2019-05-21/flat_binder_object.png)

[大图链接 `flat_binder_object`](http://www.cjcbill.com/img/bill/in-posts/2019-05-21/flat_binder_object.png)



