---
layout:     post
title:      "Jenkins搭建CTS测试环境"
summary:    '"一种自动化测试CTS的方法"'
date:       2022-03-17 22:14:07
author:     "Bill"
header-img: "img/bill/header-posts/2022-03-17-header.jpeg"
catalog: true
tags:
    - default
---


<!-- vim-markdown-toc GFM -->

* [1. 背景](#1-背景)
* [2. Jenkins](#2-jenkins)
* [3. 环境搭建](#3-环境搭建)
* [4. 测试脚本示例](#4-测试脚本示例)
* [5. 邮件通知](#5-邮件通知)

<!-- vim-markdown-toc -->

# 1. 背景

最近负责CTS测试工作，但是经常需要手动去测，且由于系统，网络等原因，测试过程中偶会发生异常，然后需要进行重测。于是想到Jenkins可以代替完成这一系列的自动化工作。

# 2. Jenkins

Jenkins的Demo在官网[Jenkins](https://www.jenkins.io/zh/doc/pipeline/tour/hello-world/)可以很方便查阅到，较低Ubuntu版本的可以选择使用Apache+jenkins.war的方式进行配置，高版本或者Mac上可以直接通过apt install或brew install的方式安装了。由于在运行时遇到一些异常，所以抛弃了使用Docker方式的配置。

与以往直接跑脚本的配置方式不一样，发现Jenkins支持了一种Groovy形式的pipeline语法，例子如下：

```
pipeline {
    agent { docker 'python:3.5.1' }
    stages {
        stage('build') {
            steps {
                sh 'python --version'
            }
        }
    }
}
```

我决定使用了这种形式进行自动化测试搭建。

# 3. 环境搭建

CTS的测试需要有adb和aapt支持，以及Java版本是11以上，所以配置方面需要先配置环境变量，如：

```
pipeline {
    agent any
    
    environment {
        // SDK路径，如果安装了Android Studio，可以在SDKManager中查阅
        ANDROID_HOME = '...'
        // 特别指定了adb，aapt的路径
        PATH = "${env.ANDROID_HOME}/platform-tools:${env.ANDROID_HOME}/build-tools/30.0.3:${env.PATH}"
        // CTS套件路径，可以在官网下载
        CTS_HOME = "..."
    }
    ....
}    
```

如果需要执行脚本获取变量，可以在这样实现:


```
stages {
    stage('Clearing') {
        steps {
            script {
                //获取当前编译时间
                env.CTS_BUILD_TIME = sh(script:'date +%Y-%m-%d-%H-%M-%S', returnStdout: true).trim()
            }
        }
    }
```

# 4. 测试脚本示例

为了检查之前设置的环境变量是否有设置成功，可以通过printenv方式进行查看。

```
stages {
    stage('Build') {
        steps {
            sh 'printenv'
        }
    }
    stage('Test') {
        steps {
            echo 'Testing Stage'
            // 运行具体的CTS测试脚本
            sh 'xxxx'
        }
    }
    stage('Retry-1') {
        steps {
            echo 'Retry 1'
            // 运行具体的CTS重测脚本
            sh 'xxxx'
        }
    }
}
```
主要的测试逻辑方式在Test的阶段执行，目的是将CTS测试通过命令行方式跑起来。这里给出具体的测试命令，脚本可以参考实现：

```python
#!/usr/bin/python2.7
# -*- coding: UTF-8 -*-
import sys
import os

CTS_HOME=os.environ['HOME'] + '/Workspace/cts/android-cts'

if sys.argv[1] == 'CtsXXXXCaseATestCases':
    TEST=sys.argv[1]
    TEST_HOME=CTS_HOME
    TEST_TYPE='cts'
    TEST_TRADEFED='cts-tradefed'
elif sys.argv[1] == 'CtsXXXXCaseBTestCases':
    TEST=sys.argv[1]
    TEST_HOME=CTS_HOME
    TEST_TYPE='cts'
    TEST_TRADEFED='cts-tradefed'
# 这里的判断为的是支持扩展，如GTS，VTS等测试项目，使用不同套件

# 默认指定了一台设备，实际可以通过获取当前adb devices设备进行多设备测试
os.system(TEST_HOME + "/tools/" + TEST_TRADEFED + " run " + TEST_TYPE + " -m " + TEST + " --logcat-on-failure --skip-preconditions")
```

重测流程主要是对照着Session号进行重测，所以必须先得直到Result文件夹中有多少个结果，只要获取到zip包数量，就可以知道上次结果对应的session号，从而主动进行重测操作了，如：

```python
#!/usr/bin/python2.7
# -*- coding: UTF-8 -*-
import sys
import os
import time

CTS_HOME=os.environ['HOME'] + '/Workspace/cts/android-cts'
TEST_HOME=CTS_HOME
TEST_TRADEFED='cts-tradefed'

RESULT_COUNTS=0
RESULT_LISTS = []
for item in os.listdir(TEST_HOME + "/results"):
    if os.path.isdir(TEST_HOME + "/results/" + item) and item != 'latest':
        if os.path.isfile(TEST_HOME + "/results/" + item + '/test_result.xml'):
            RESULT_COUNTS += 1
            RESULT_LISTS.append(item)
# 获取上次结果的Session号
LAST_SESSION = RESULT_COUNTS - 1 

# 当多个测试同时进行时，无法保证最新一次的result对应的session号就是需要重测的session。
# 但是latest对应的session一定是需要重测的session, 所以可以通过排序最新的，然后对比latest软连接的名字
# 得出重测对应的session号
REAL_RESULT_PATH=os.path.basename(os.path.realpath(TEST_HOME + "/results/latest"))
for index, item in enumerate(sorted(RESULT_LISTS)):    
    if item == REAL_RESULT_PATH:    
        #LAST_SESSION = LAST_SESSION - 1    
        LAST_SESSION = index    
        break  

# 根据session执行重测
os.system(TEST_HOME + "/tools/" + TEST_TRADEFED + " run retry --retry " + str(LAST_SESSION) + " --logcat-on-failure " + " -s " + DEVICE_SERIAL)
```

# 5. 邮件通知

测试结束后可以通过mailext插件将日志和结果进行发送，具体示例如下:


```
post {
  always {
    // 将日志放到result文件夹一起进行压缩
    sh "cd ${env.RESULT_HOME}/latest && cp -rf  ../../logs/latest/inv* logs && zip -r ${env.WORKSPACE}/${env.EMAIL_ATTACHMENT}-${env.CTS_BUILD_TIME}.zip . && cd -"
    emailext(
       body: "${env.TEST_CASE} test finished",
       subject: "${env.JOB_NAME} - Build # ${env.BUILD_NUMBER}-JENKINS-${env.TEST_CASE}-TEST-REPORT",
       // 发送目标可以通过环境变量设置，可以发送给多个收件人，使用逗号分割
       to: "${env.EMAIL_TARGET}",
       // 作为附件进行发送
       attachmentsPattern: "**/${env.EMAIL_ATTACHMENT}-${env.CTS_BUILD_TIME}.zip"
       )
    // 清理本次附件
    sh "rm ${env.WORKSPACE}/${env.EMAIL_ATTACHMENT}-${env.CTS_BUILD_TIME}.zip"
  }
}
```

