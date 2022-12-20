---
layout:     post
title:      "实用Shell技术整理"
summary:    '"A shell script is a computer program designed to be run by the Unix shell, a command-line interpreter"'
date:       2019-07-04 23:11:38
author:     "Bill"
header-img: "img/bill/header-posts/2019-07-04.jpg"
catalog: true
tags:
    - shell
---


<!-- vim-markdown-toc GFM -->

* [1. Shell 循环](#1-shell-循环)
    * [1.1 类c语言](#11-类c语言)
    * [1.2 in使用](#12-in使用)
    * [1.3 seq使用](#13-seq使用)
* [2. 提供选择](#2-提供选择)
* [3. `BASH_SOURCE`](#3-bash_source)
* [4. print red](#4-print-red)
* [5. Extract file Name](#5-extract-file-name)
* [6. 比较字符(不考虑大小写)](#6-比较字符不考虑大小写)
* [7. 远程登录并执行命令](#7-远程登录并执行命令)
* [8.修改文件夹内所有文件](#8修改文件夹内所有文件)
* [9.替换当前文件夹内所有关键字](#9替换当前文件夹内所有关键字)
* [10. awk常用用法](#10-awk常用用法)
* [11. 对比字符串是否含有指定字符](#11-对比字符串是否含有指定字符)
* [12. If判断](#12-if判断)
    * [12.1 判断文件/文件夹](#121-判断文件文件夹)
    * [12.2 字符串判断](#122-字符串判断)
* [13. 修改文件夹和文件的权限](#13-修改文件夹和文件的权限)

<!-- vim-markdown-toc -->


# 1. Shell 循环

## 1.1 类c语言

```shell
for ((i=1; i<=100; i ++))
do
    echo $i
done
```

## 1.2 in使用

```shell
[for i in {1..100}
do
    echo $i
done
```

## 1.3 seq使用

```shell
for i in `seq 1 100`
do
    echo $i
done
```

倒数
```shell
for i in `seq 9 -1 0`
do
...
done
```

# 2. 提供选择

```shell
select ntype in "A" "B"
do
    case $ntype in
        "A")
        #do something
        break
        ;;
        "B")
        #do something too
        break
        ;;
    esac
done

```

# 3. `BASH_SOURCE`
`BASH_SOURCE[0]` 等价于 `BASH_SOURCE`， 取得当前执行的shell文件所在的路径及文件名。


```shell
#!/bin/bash
echo "${BASH_SOURCE[0]}"
echo "${BASH_SOURCE}"
echo "$( dirname "${BASH_SOURCE[0]}" )"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR
```

out:

```shell
bill@ThinkPad:~$ /tmp/test.sh
/tmp/test.sh
/tmp/test.sh
/tmp
/tmp
```

# 4. print red

```shell
Black        0;30     Dark Gray     1;30
Red          0;31     Light Red     1;31
Green        0;32     Light Green   1;32
Brown/Orange 0;33     Yellow        1;33
Blue         0;34     Light Blue    1;34
Purple       0;35     Light Purple  1;35
Cyan         0;36     Light Cyan    1;36
Light Gray   0;37     White         1;37
```

```shell
#    .---------- constant part!
#    vvvv vvvv-- the code from above
RED='\033[0;31m'
NC='\033[0m' # No Color
printf "I ${RED}love${NC} Stack Overflow\n"
```

当使用echo时需要加`-e`

```shell
# Continued from above example
echo -e "I ${RED}love${NC} Stack Overflow"
```

# 5. Extract file Name

```shell
filename=$(basename -- "$apkPath")
extension="${filename##*.}"
filename="${filename%.*}"
```

- `${parameter#word}`
- `${parameter##word}`

> The word is expanded to produce a pattern just as in filename expansion (see Filename Expansion). If the pattern matches the beginning of the expanded value of parameter, then the result of the expansion is the expanded value of parameter with the shortest matching pattern (the ‘#’ case) or the longest matching pattern (the ‘##’ case) deleted. If parameter is ‘@’ or ‘*’, the pattern removal operation is applied to each positional parameter in turn, and the expansion is the resultant list. If parameter is an array variable subscripted with ‘@’ or ‘*’, the pattern removal operation is applied to each member of the array in turn, and the expansion is the resultant list.

- `${parameter%word}`
- `${parameter%%word}`

> The word is expanded to produce a pattern just as in filename expansion. If the pattern matches a trailing portion of the expanded value of parameter, then the result of the expansion is the value of parameter with the shortest matching pattern (the ‘%’ case) or the longest matching pattern (the ‘%%’ case) deleted. If parameter is ‘@’ or ‘*’, the pattern removal operation is applied to each positional parameter in turn, and the expansion is the resultant list. If parameter is an array variable subscripted with ‘@’ or ‘*’, the pattern removal operation is applied to each member of the array in turn, and the expansion is the resultant list.

```shell
假设定义了一个变量为：
代码如下:
file=/dir1/dir2/dir3/my.file.txt
可以用${ }分别替换得到不同的值：
${file#*/}：删掉第一个 / 及其左边的字符串：dir1/dir2/dir3/my.file.txt
${file##*/}：删掉最后一个 /  及其左边的字符串：my.file.txt
${file#*.}：删掉第一个 .  及其左边的字符串：file.txt
${file##*.}：删掉最后一个 .  及其左边的字符串：txt
${file%/*}：删掉最后一个  /  及其右边的字符串：/dir1/dir2/dir3
${file%%/*}：删掉第一个 /  及其右边的字符串：(空值)
${file%.*}：删掉最后一个  .  及其右边的字符串：/dir1/dir2/dir3/my.file
${file%%.*}：删掉第一个  .   及其右边的字符串：/dir1/dir2/dir3/my
记忆的方法为：
# 是 去掉左边（键盘上#在 $ 的左边）
%是去掉右边（键盘上% 在$ 的右边）
单一符号是最小匹配；两个符号是最大匹配
${file:0:5}：提取最左边的 5 个字节：/dir1
${file:5:5}：提取第 5 个字节右边的连续5个字节：/dir2
也可以对变量值里的字符串作替换：
${file/dir/path}：将第一个dir 替换为path：/path1/dir2/dir3/my.file.txt
${file//dir/path}：将全部dir 替换为 path：/path1/path2/path3/my.file.txt
```

# 6. 比较字符(不考虑大小写)

```shell
var1=TesT
var2=tEst

echo ${var1,,} ${var2,,}
echo ${var1^^} ${var2^^}
```

前者都转化为小写，后者都转化为大写

# 7. 远程登录并执行命令

```shell
ssh -t [user]@[remote address] '脚本命令; bash'
```

# 8.修改文件夹内所有文件

比如需要将`ani1280_00.png`格式的所有图片换成`ani1920_00.png`

```shell
$ rename 's/1280/1920/g' *.png
```

# 9.替换当前文件夹内所有关键字

```shell
$ find . -type f -exec sed -i 's/A/B/g' {} +
```

或者屏蔽.git目录为例子，如下所示:

```shell
find /home/www \( -type d -name .git -prune \) -o -type f -print0 | xargs -0 sed -i 's/subdomainA\.example\.com/subdomainB.example.com/g'
```

# 10. awk常用用法

打印第一列:

```shell
awk '{print $1}'
```

打印指定列数:

```shell
awk -F " " '{for(i=1;i<=NF;i++)printf("%s ",$i);printf "\n"}' file
```

如想在ps中打印除第一列的内容:


```shell
ps | awk -F " " '{for(i=2;i<=NF;i++)printf("%s ",$i);printf "\n"}'
```


# 11. 对比字符串是否含有指定字符

```shell
str1="Monkey Money"
str2="Monkey"
result=$(echo $str1 | grep -i "$str2")
if [[ "$result" != "" ]];then
    echo "contain!"
else
    echo "not contain"
fi
```

# 12. If判断 

## 12.1 判断文件/文件夹

- [ -b FILE ] 如果 FILE 存在且是一个块特殊文件则为真。
- [ -c FILE ] 如果 FILE 存在且是一个字特殊文件则为真。
- [ -d DIR ] 如果 FILE 存在且是一个目录则为真。
- [ -e FILE ] 如果 FILE 存在则为真。
- [ -f FILE ] 如果 FILE 存在且是一个普通文件则为真。
- [ -g FILE ] 如果 FILE 存在且已经设置了SGID则为真。
- [ -k FILE ] 如果 FILE 存在且已经设置了粘制位则为真。
- [ -p FILE ] 如果 FILE 存在且是一个名字管道(F如果O)则为真。
- [ -r FILE ] 如果 FILE 存在且是可读的则为真。
- [ -s FILE ] 如果 FILE 存在且大小不为0则为真。
- [ -t FD ] 如果文件描述符 FD 打开且指向一个终端则为真。
- [ -u FILE ] 如果 FILE 存在且设置了SUID (set user ID)则为真。
- [ -w FILE ] 如果 FILE存在且是可写的则为真。
- [ -x FILE ] 如果 FILE 存在且是可执行的则为真。
- [ -O FILE ] 如果 FILE 存在且属有效用户ID则为真。
- [ -G FILE ] 如果 FILE 存在且属有效用户组则为真。
- [ -L FILE ] 如果 FILE 存在且是一个符号连接则为真。
- [ -N FILE ] 如果 FILE 存在 and has been mod如果ied since it was last read则为真。
- [ -S FILE ] 如果 FILE 存在且是一个套接字则为真。
- [ FILE1 -nt FILE2 ] 如果 FILE1 has been changed more recently than FILE2, or 如果 FILE1 exists and FILE2 does not则为真。
- [ FILE1 -ot FILE2 ] 如果FILE1比FILE2要老,或者 FILE2 存在且FILE1不存在则为真。
- [ FILE1 -ef FILE2 ] 如果FILE1和FILE2指向相同的设备和节点号则为真。

## 12.2 字符串判断 

- [ -z STRING ] 如果STRING的长度为零则为真,即判断是否为空，空即是真；
- [ -n STRING ] 如果STRING的长度非零则为真,即判断是否为非空，非空即是真；
- [ STRING1 = STRING2 ] 如果两个字符串相同则为真；
- [ STRING1 != STRING2 ] 如果字符串不相同则为真；
- [ STRING1 ]　 如果字符串不为空则为真,与-n类似

# 13. 修改文件夹和文件的权限

在提交代码时，对文件夹和文件的权限可进行递归修改，没有必要的权限不要赋给文件，修改如下：

```shell
sudo find foldername -type d -exec chmod 755 {} ";"
sudo find foldername -type f -exec chmod 644 {} ";"
```
