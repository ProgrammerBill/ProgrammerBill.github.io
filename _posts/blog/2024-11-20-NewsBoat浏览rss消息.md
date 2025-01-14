---
author: Bill
catalog: true
date: '2024-11-20'
guitartab: false
header-img: img/bill/header-posts/2024-01-24-header.png
hide: false
layout: post
life: false
stickie: false
summary: '"NewsBoat浏览rss消息"'
tags: []
title: NewsBoat浏览rss消息
---

# 背景

由于平日工作太忙，抽不出大段时间获取咨询，因此在碎片化的时间能够浏览下新闻或者博客成了我的强烈需求，希望能够在终端中能够查阅新闻。

# rss

通过ChatGpt了解到，rss正可以满足我的需求，它给出的定义如下：

```
RSS（Really Simple Syndication）是一种基于XML的格式，用于分发和共享内容。通过RSS，用户可以订阅网站、博客、新闻频道等内容源，并及时获取更新的内容而无需访问网站。
```

rss不是新的技术，一般大型网站都有支持，比如以知乎的rss为例：

```
https://www.zhihu.com/rss
```

可以看到内容是以基于xml的方式定义的，如果选择一款基于终端的阅读器，就可以快速的实现新闻阅读了。而AI推荐的阅读器名为NewsBoat。其网址如下：

```
https://newsboat.org/index.html
```

用户可以选择使用源码安装，但我的环境安装的依赖较多，于是选择使用snap安装。


# 数据源

rss的订阅源可以通过修改url指定，而config可以做一些定制化的动作，比如我更喜欢vim的操作方式，就可以使用vim的键值绑定，个人的newsBoat配置，在如下链接：

```
https://github.com/ProgrammerBill/bill-newsboat-config
```

可以愉快的利用碎片化时间阅读啦。

![selection_174.png](images/WEBRESOURCEe8f8660d375b28397177dd46ccd08fc2Selection_174.png)



