---
layout:     post
title:      "C++ Core Guidelines学习"
subtitle:   " \"cpp/c\""
summary:    '"cpp/c"'
date:       2021-07-14 09:50:00
author:     "Bill"
header-img: "img/bill/header-posts/2021-07-14.png"
catalog: true
tags:
    - c++
---


<!-- vim-markdown-toc GFM -->

* [1. 背景](#1-背景)
* [2. Philosophy](#2-philosophy)
    * [2.1 P.1: Express ideas directly in code](#21-p1-express-ideas-directly-in-code)
    * [2.2 P.2: Write in ISO Standard C++](#22-p2-write-in-iso-standard-c)
    * [2.3 P.3: Express intent](#23-p3-express-intent)
    * [2.4 P.4: Ideally, a program should be statically type safe](#24-p4-ideally-a-program-should-be-statically-type-safe)
    * [2.5 P.5: Prefer compile-time checking to run-time checking](#25-p5-prefer-compile-time-checking-to-run-time-checking)

<!-- vim-markdown-toc -->

# 1. 背景

随着Android平台不断迭代升级，使用的新的C++技术也越来越让我费解了，本着想要看看新的C++技术的目的，发现了这篇由Bjarne Stroustrup的对于Modern C++的技术讲解，也在这里作为一个学习笔记记录。
网址是[C++ Core Guidelines](http://isocpp.github.io/CppCoreGuidelines).


# 2. Philosophy

## 2.1 P.1: Express ideas directly in code

意思是在代码里面表达想法。当然我们工作的时候可以通过文档，注释等对代码进行解释，但是如果将想要表达的意图蕴含在代码里会让开发者更容易看懂，比如文档中的例子:


不好的例子:

```
void f(vector<string>& v)
{
    string val;
    cin >> val;
    // ...
    int index = -1;                    // bad, plus should use gsl::index
    for (int i = 0; i < v.size(); ++i) {
        if (v[i] == val) {
            index = i;
            break;
        }
    }
    // ...
}
```

好的例子:

```
void f(vector<string>& v)
{
    string val;
    cin >> val;
    // ...
    auto p = find(begin(v), end(v), val);  // better
    // ...
}
```

两个例子的目标是都是一致的，但明显后者在语义上来看更直观。额外以一个例子对比下find的效率，并加入一个set的例子.
:

```c++
#include<iostream>
#include<algorithm>
#include<vector>
#include<set>
#include<climits>

#include <stdio.h>
#include <sys/time.h>
#include <unistd.h>

using namespace std; class Time {
 public:
  Time(){}
  ~Time(){}

  void start()
  {
    gettimeofday(&tv1,nullptr);
  }

  int end()
  {
    gettimeofday(&tv2,nullptr);
    return (1000000*(tv2.tv_sec - tv1.tv_sec) + (tv2.tv_usec - tv1.tv_usec));
  }
 private:
  struct timeval tv1, tv2;
};

void fun1(vector<int>& v, int val)
{
    auto p = find(begin(v), end(v), val);  // better
    cout<<"fun1 val = "<<*p<<endl;
}

void fun2(vector<int>& v, int val)
{
    int index = -1;                    // bad, plus should use gsl::index
    for (int i = 0; i < v.size(); ++i) {
        if (v[i] == val) {
            index = i;
            break;
        }
    }
    cout<<"fun2 val = "<<v[index]<<endl;
}

void fun3(set<int>& v, int val)
{
    auto p = v.find(val);
    cout<<"fun3 val = "<<*p<<endl;
}

int main() {
  Time time;
  vector<int> input;
  set<int> sinput;
  const int counts = 1<<25;
  for (int i = 0; i<=counts; i++) {
    input.push_back(i); 
    sinput.insert(i); 
  }
  time.start();
  fun1(input, counts);
  cout<<" func1 cost "<<time.end()<<endl;;
  time.start();
  fun2(input, counts);
  cout<<" func2 cost "<<time.end()<<endl;
  time.start();
  fun3(sinput, counts);
  cout<<" func3 cost "<<time.end()<<endl;
}
```

输出:

```
fun1 val = 33554432
 func1 cost 221844
fun2 val = 33554432
 func2 cost 186391
fun3 val = 33554432
 func3 cost 8
```

可以找到的值都一致，但效率上却还是有区别的。std::find和遍历找的方式的时间复杂度都是O(n),但set的是基于平衡树的方式找数据，得出来的速度也是很快。当然这是一个例子，
在不影响效率的前提下，应当选择更容易读懂的方式。

## 2.2 P.2: Write in ISO Standard C++

在某些环境中，C++扩展是必须的，但是并不是所有环境支持这些扩展的，建议控制这些扩展的使用，可以在扩展之上再通过封装一层接口层，用于控制是否使用这些扩展。以便在不支持这些扩展的系统环境中也能够正常使用。虽然扩展很方便，也在很多不同的编译器有相应的实现，但是由于没有严格定义的语义，导致可能会在不同的平台中有不同的表现。所以还是使用ISO标准的C++会更可靠。

## 2.3 P.3: Express intent 

写代码除非通过函数名，注释等表明是要做什么的，否则根本不知道它是要干什么的。以如下一个例子为例：

```c++
gsl::index i = 0;
while (i < v.size()) {
    // ... do something with v[i] ...
    }
```
这是一段典型的看了不能明确其目标的代码，首先i被暴露出来了，就会有被误用的可能性，且i的生命周期比循环要更长，也就不好明确代码的用意是什么。假如不需要修改元素，更好的写法是：

```c++
for (const auto& x : v) { /* do something with the value of x */ }
```
由于不需要修改元素，可以加上const来防止被修改。读者看了这段代码就会明白，这只是一个单纯的循环来获取值。假如需要改值，可以这样写：

```c++
for (auto& x : v) { /* modify x */ }
```
有时候使用有名算法会更好，可以使用`for_each`的写法, 第三个参数可以加上具体的算法函数，可以让读者更清楚想要实现的目的。如：

```c++
for_each(v, [](int x) { /* do something with the value of x */ });
for_each(par, v, [](int x) { /* do something with the value of x */ });
```

为了表达代码的意图，可以通过构建的方式，来展示，如下面这个画线的例子,前者明显比较难懂，一堆参数放在那里，但后者以两点作为传参，就很清晰明了。

```c++
draw_line(int, int, int, int);  // obscure
draw_line(Point, Point);        // clearer
```

## 2.4 P.4: Ideally, a program should be statically type safe

一个程序应该保证是静态类型安全, 它的意思是，只要通过了静态类型检查，就能够保证程序没有问题。但是这是不可能的事情，可能会引发问题的是包括:

- unions联合体
- casts强制转换
- array decay数组名转化为指针
- range erros
- narrowing conversions

unions为例，它可以包含多种类型不同的成员且占用相同的地址, 如下:

```c
#include<stdio.h>
union data{
    int n;
    char ch;
    double f;
};
int main() {
    union data test = {123};
    test.ch = 'b';
    printf("%d %c\n", test.n, test.ch);
    printf("%p %p\n", &test.n, &test.ch);
}
```

输出:

```
98 b
0x7ffc3f21eb00 0x7ffc3f21eb00
```

可以看出，由于ch被设置为字符'b'了，所以之前的成员变量n也会被覆盖，因为union用的是相同地址。虽然这样并不会在编译阶段检查出错误，但是一旦调用了其余类型不同的成员时，就会导致数据异常。

casts的情况也容易理解，upcast和downcast，前者是安全的，但后者是非安全的。

```
class Parent {
public:
  void sleep() {}
};

class Child: public Parent {
private:
  std::string classes[10];
public:
  void gotoSchool(){}
};

int main( ) 
{ 
  Parent *pParent = new Parent;
  Parent *pChild = new Child;
    
  Child *p1 = (Child *) pParent;  // #1
  p1->gotoSchool();
  Parent *p2 = (Child *) pChild;  // #2
  p2->sleep();
  return 0; 
}
```
前者的downcast转换是非安全的，因为它将一个基类的地址传给了子类，所以在代码中就会期待基类对象能够有子类对象的属性，比如这里的gotoSchool函数，但实际上基类对象是没有的。

array decay,通常数组可以通过sizeof(array)/sizeof(数组类型)来获取数组长度信息，但如果将数组传入到其他的块作用域下，就没办法通过这样来获取长度信息。


```c++
#include<iostream>
#include<string>
using namespace std;

// Driver function to show Array decay
// Passing array by value
void aDecay(int *p)
{
    // Printing size of pointer
    cout << "Modified size of array is by "
        " passing by value: ";
    cout << sizeof(p) << endl;
}

// Function to show that array decay happens
// even if we use pointer
void pDecay(int (*p)[7])
{
    // Printing size of array
    cout << "Modified size of array by "
        "passing by pointer: ";
    cout << sizeof(p) << endl;
}

int main()
{
    int a[7] = {1, 2, 3, 4, 5, 6, 7,};

    // Printing original size of array
    cout << "Actual size of array is: ";
    cout << sizeof(a) <<endl;

    // Passing a pointer to array as an array is always passed by reference
    aDecay(a);

    // Calling function by pointer
    pDecay(&a);

    return 0;
}
```

输出:

```
Actual size of array is: 28
Modified size of array is by  passing by value: 8
Modified size of array by passing by pointer: 8
```

## 2.5 P.5: Prefer compile-time checking to run-time checking 

即优先选择编译的检查，而非运行时的检查，这样就不需要写一些运行时的错误处理了(机智).
如文中给出的一个例子,对Int进行左移，但由于Int是alias，有可能会导致溢出后仍然大于0的情形:


```
// Int is an alias used for integers
int bits = 0;         // don't: avoidable code
for (Int i = 1; i; i <<= 1)
    ++bits;
if (bits < 32)
    cerr << "Int too small\n";
```

但只要适时加入静态检查，就可以避免这种未知行为的产生:

```
// Int is an alias used for integers
static_assert(sizeof(Int) >= 4);    // do: compile-time check
```

当然更好的方法不是使用这种Int的别名，而是直接用`int32_t`这种明确的类型。

Guideline还举了一个例子，如使用C风格的方式，容易超出下标导致运行时发生越界的段错误:

```
void read(int* p, int n);   // read max n integers into *p

int a[100];
read(a, 1000);    // bad, off the end
better
```

使用span可以解决这类问题，在编译阶段就可以检查出来。

```
void read(span<int> r); // read into the range of integers r
int a[100];
read(a);        // better: let the compiler figure out the number of elements
```

这里使用的span是gsl库中类型，可以去官网[](https://github.com/microsoft/GSL)进行下载安装。
