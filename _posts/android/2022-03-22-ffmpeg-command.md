---
layout:     post
title:      "FFmpeg Experience"
summary:    '"记录一些关于FFmpeg有用的指令"'
date:       2022-03-22 14:49:56
author:     "Bill"
header-img: "img/bill/header-posts/2022-03-22-header.jpg"
catalog: true
tags:
    - default
---


<!-- vim-markdown-toc GFM -->

* [1. 视频](#1-视频)
    * [1.1 分辨率相关](#11-分辨率相关)
        * [1.1.1 分辨率转换](#111-分辨率转换)
        * [1.1.2 分辨率拼接](#112-分辨率拼接)
    * [1.2 播放码流](#12-播放码流)
    * [1.3 播放YUV](#13-播放yuv)
* [2. 图片](#2-图片)
    * [2.1 格式转换](#21-格式转换)
* [3. 查看视频包信息](#3-查看视频包信息)

<!-- vim-markdown-toc -->

# 1. 视频

## 1.1 分辨率相关

### 1.1.1 分辨率转换

```
ffmpeg -i [input] -vf scale=[width]:[height] -vcodec [codec type] [output]
```

### 1.1.2 分辨率拼接

首先制作一系列分辨率不同的视频，以mpeg2为例:

```
ffmpeg -i [input] -vf scale=[width]:[height] -vcodec mpeg2video [output]
```

假设输入有多个文件，先创建文件mylist.txt


```
# this is a comment
file '/path/to/file1.mp4'
file '/path/to/file2.mp4'
file '/path/to/file3.mp4'
```

执行拼接操作:

```
ffmpeg -f concat -safe 0 -i mylist.txt -c copy output.mp4
```

## 1.2 播放码流

```
ffplay [bitstream file]
```

## 1.3 播放YUV


```
ffplay -f rawvideo -video_size [widthxheight] [input YUV]
```

# 2. 图片

## 2.1 格式转换

如webp转jpeg可以执行:

```
ffmpeg -i [src] [dst.jpg]
```

# 3. 查看视频包信息

```
ffprobe -show_packets [input.mp4] > output.log
```
