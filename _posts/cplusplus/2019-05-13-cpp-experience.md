---
layout:     post
title:      "C++/C 常见技术点笔记"
subtitle:   " \"cpp/c\""
date:       2019-05-13 16:10:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-05-13.jpg"
catalog: true
tags:
    - c++
---


<!-- vim-markdown-toc GFM -->

* [1. 背景](#1-背景)
* [2. C++类型转换](#2-c类型转换)
	* [2.1 `static_cast`](#21-static_cast)
	* [2.2 `dynamic_cast`](#22-dynamic_cast)
	* [2.3 `const_cast`](#23-const_cast)
	* [2.4 `reinterpret_cast`](#24-reinterpret_cast)
* [3. 常用类型转换](#3-常用类型转换)
	* [3.1 string与char \*转换](#31-string与char-转换)

<!-- vim-markdown-toc -->

# 1. 背景

受到之前整理Git的问题点的启发，在Android Native层开发或者日常学习过程，也会遇到很多问题，于是想把开发中关于C++/C的技术点记录下来，方便以后查询。



# 2. C++类型转换

## 2.1 `static_cast`

`static_cast`相当于传统的C语言里的强制转换，该运算符把expression转换为new_type类型，用来强迫隐式转换如non-const对象转为const对象，编译时检查，用于非多态的转换，可以转换指针及其他，但没有运行时类型检查来保证转换的安全性。它主要有如下几种用法：

1. 用于类层次结构中基类（父类）和派生类（子类）之间指针或引用的转换。 
进行上行转换（把派生类的指针或引用转换成基类表示）是安全的； 
进行下行转换（把基类指针或引用转换成派生类表示）时，由于没有动态类型检查，所以是不安全的。 
2. 用于基本数据类型之间的转换。
3. 把空指针转换成目标类型的空指针。 
4. 把任何类型的表达式转换成void类型。 

假设类之间关系如下:

```c++
class Base{
public:
    Base(){}
    //not virtual func
    void func(){
        cout<<"Base"<<endl;
    

    virtual void func_v(){
        cout<<"Base:func_v"<<endl;
    }
};

class Child :public Base{
public:
    Child(){}
    void func(){
        cout<<"Child"<<endl;
    }
    
    virtual void func_v(){
        cout<<"Child:func_v"<<endl;
    }

    void extendFunc(){
        cout<<"Child:extendFunc"<<endl;
    }
};

```

上行转换，安全转换:
```c++
    Child * mChild = new Child();
    mChild->func();

    Base * mBase = static_cast<Base*>(mChild);
    mBase->func();
```

下行转换，非安全转换:

```c++
    //Not Safe static_cast form Base to Child
    Base * mBase = new Base();
    Child * mChild = static_cast<Child*>(mBase); 
```

基本类型转换:

```c++
    char a = 'a';
    int b = static_cast<char>(a);

    double *c = new double(101);
    void *d = static_cast<void *>(c); 

    int e = 10;
    const int f = static_cast<const int>(e); 
```


## 2.2 `dynamic_cast`

`dynamic_cast`主要用于类层次间的上行转换和下行转换，还可以用于类之间的交叉转换（cross cast）。
在类层次间进行上行转换时，`dynamic_cast`和`static_cast`的效果是一样的；在进行下行转换时，`dynamic_cast`具有类型检查的功能，比`static_cast`更安全。`dynamic_cast`是唯一无法由旧式语法执行的动作，也是唯一可能耗费重大运行成本的转型动作。


## 2.3 `const_cast`

`const_cast`用来将类型的const、volatile和`__unaligned`属性移除。常量指针被转换成非常量指针，并且仍然指向原来的对象；常量引用被转换成非常量引用，并且仍然引用原来的对象


## 2.4 `reinterpret_cast`

允许将任何指针类型转换为其它的指针类型；听起来很强大，但是也很不靠谱。它主要用于将一种数据类型从一种类型转换为另一种类型。它可以将一个指针转换成一个整数，也可以将一个整数转换成一个指针，在实际开发中，先把一个指针转换成一个整数，在把该整数转换成原类型的指针，还可以得到原来的指针值；特别是开辟了系统全局的内存空间，需要在多个应用程序之间使用时，需要彼此共享，传递这个内存空间的指针时，就可以将指针转换成整数值，得到以后，再将整数值转换成指针，进行对应的操作。


# 3. 常用类型转换

## 3.1 string与char \*转换

```c++
string b = "xxxx";
const char *a = b.c_str();
```
