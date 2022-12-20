---
layout:     post
title:      "Android Studio导入项目说明"
summary:    '"Android Studio"'
date:       2019-01-17 11:08:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-01-17.jpg"
catalog: true
tags:
    - android
---


<!-- vim-markdown-toc GFM -->

* [1.前言](#1前言)
* [2. 修改gradle插件版本](#2-修改gradle插件版本)
* [3.修改SdkVersion](#3修改sdkversion)
* [4.修改gradle路径](#4修改gradle路径)
* [5.修改工具或依赖库的版本号](#5修改工具或依赖库的版本号)

<!-- vim-markdown-toc -->

# 1.前言

在实际开发过程中，有时候需要导入其他环境的项目，这时候如果和个人的环境不匹配，编译就会报错，现在简单记录下修改的流程,以便后续能快速开发。

# 2. 修改gradle插件版本

一般通过AndroidStudio标题即可确定gradle插件版本

![](/img/bill/in-posts/2019-01-17/1.png)

此时可以修改build.gradle至一致：

![](/img/bill/in-posts/2019-01-17/2.png)

```
buildscript {
    repositories {
        jcenter()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:2.3.3'

        // NOTE: Do not place your application dependencies here; they belong
        // in the individual module build.gradle files
    }
}
```

# 3.修改SdkVersion

不同项目针对的SdkVersion会有差异，针对环境和机型，确定SdkVersion:

```
#/app/build.gradle
    compileSdkVersion 26
    buildToolsVersion "23.0.2"
    defaultConfig {
        applicationId "me.veryyoung.dingding.luckymoney"
        minSdkVersion 15
        targetSdkVersion 23
        versionCode 43
        versionName "1.3.6"
    }
```

# 4.修改gradle路径

gradle的版本号需要和本地设置一致，可以参考以往的gradle-wrapper.properties

```
#gradle/wrapper/gradle-wrapper.properties

#Fri Oct 21 20:39:47 CST 2016
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-4.1-all.zip
```

# 5.修改工具或依赖库的版本号

在以上都修改好后，还很可能会提示工具的版本问题，如：

![](/img/bill/in-posts/2019-01-17/3.png)

此时可以选择更新或者与以往仓库一致，详细可参考build.gradle

![](/img/bill/in-posts/2019-01-17/4.png)

由于SDK的版本与工具的最低版本号可能有要求，所以可以根据提示修改build.gradle至SDK要求的最低版本并进行更新:

在dependencies也需要与环境的一致:

```
dependencies {
    provided files('libs/XposedBridgeApi-82.jar')
    compile 'com.android.support:appcompat-v7:23.1.1'
}
```

此时可以通过"File/Project Structure/Dependencies"中选择以后的同类库进行替换。

![](/img/bill/in-posts/2019-01-17/5.png)


