---
layout:     post
title:      "Android 笔试题目汇总"
summary:    '"Android 笔试"'
date:       2019-02-25 00:41:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-02-25.jpg"
catalog: true
tags:
    - android
---


<!-- vim-markdown-toc GFM -->

* [1.java面试题](#1java面试题)
	* [1.1 java中==和equals和hashCode的区别](#11-java中和equals和hashcode的区别)
	* [1.2 int、char、long各占多少字节数](#12-intcharlong各占多少字节数)
	* [1.3 int与integer的区别](#13-int与integer的区别)
	* [1.4 谈谈对java多态的理解](#14-谈谈对java多态的理解)
	* [1.5 String、StringBuffer、StringBuilder区别](#15-stringstringbufferstringbuilder区别)
	* [1.6 什么是内部类？内部类的作用](#16-什么是内部类内部类的作用)

<!-- vim-markdown-toc -->

# 1.java面试题
熟练掌握java是很关键的，大公司不仅仅要求你会使用几个api，更多的是要你熟悉源码实现原理，甚至要你知道有哪些不足，怎么改进，还有一些java有关的一些算法，设计模式等等。
（一） java基础面试知识点

## 1.1 java中==和equals和hashCode的区别

- java ==

java中的数据类型，可分为两类：

1.基本数据类型，也称原始数据类型

byte,short,char,int,long,float,double,boolean   他们之间的比较，应用双等号（==）,比较的是他们的值。

2.引用类型(类、接口、数组)

当他们用（==）进行比较的时候，比较的是他们在内存中的存放地址，所以，除非是同一个new出来的对象，他们的比较后的结果为true，否则比较后结果为false。

对象是放在堆中的，栈中存放的是对象的引用（地址）。由此可见'=='是对栈中的值进行比较的。如果要比较堆中对象的内容是否相同，那么就要重写equals方法了。

```
public class Solution {
    public static void main(String[] args) {
        int int1 = 12;
        int int2 = 12;
        Integer Integer1 = new Integer(12);
        Integer Integer2 = new Integer(12);
        Integer Integer3 = new Integer(127);

        Integer a1 = 127;
        Integer b1 = 127;

        Integer a = 128;
        Integer b = 128;

        String s1 = "str";
        String s2 = "str";
        String str1 = new String("str");
        String str2 = new String("str");

        System.out.println("int1==int2:" + (int1 == int2));
        System.out.println("int1==Integer1:" + (int1 == Integer1));
        System.out.println("Integer1==Integer2:" + (Integer1 == Integer2));
        System.out.println("Integer3==b1:" + (Integer3 == b1));
        System.out.println("a1==b1:" + (a1 == b1));
        System.out.println("a==b:" + (a == b));
        System.out.println("s1==s2:" + (s1 == s2));
        System.out.println("s1==str1:" + (s1 == str1));
        System.out.println("str1==str2:" + (str1 == str2));
    }
}
```

输出:

```
int1==int2:true
int1==Integer1:true //Integer会自动拆箱为int，所以为true
Integer1==Integer2:false//不同对象，在内存存放地址不同，所以为false
Integer3==b1:false//Integer3指向new的对象地址，b1指向缓存中127地址，地址不同，所以为false
a1==b1:true
a==b:false
s1==s2:true
s1==str1:false
str1==str2:false
```

Integer b1 = 127;java在编译的时候,被翻译成-> Integer b1 = Integer.valueOf(127);

```
public static Integer valueOf(int i) {
     assert IntegerCache.high >= 127;
     if (i >= IntegerCache.low && i <= IntegerCache.high)
         return IntegerCache.cache[i + (-IntegerCache.low)];
     return new Integer(i);
 }
```

对于-128到127之间的数，会进行缓存，Integer b1 = 127时，会将127进行缓存，下次再写Integer i6 = 127时，就会直接从缓存中取，就不会new了。所以a1==b1:true  a==b:false


- java equals

默认情况（没有覆盖equals方法）下equals方法都是调用Object类的equals方法，而Object的equals方法主要用于判断对象的内存地址引用是不是同一个地址（是不是同一个对象）。下面是Object类中equals方法

```
public boolean equals(Object obj) {
    return (this == obj);
}
```

定义的equals与==是等效的

要是类中覆盖了equals方法，那么就要根据具体的代码来确定equals方法的作用了，覆盖后一般都是通过对象的内容是否相等来判断对象是否相等。下面是String类对equals进行了重写:

```
public boolean equals(Object anObject) {
    if (this == anObject) {
        return true;
    }
    if (anObject instanceof String) {
        String anotherString = (String)anObject;
        int n = count;
        if (n == anotherString.count) {
        char v1[] = value;
        char v2[] = anotherString.value;
        int i = offset;
        int j = anotherString.offset;
        while (n-- != 0) {
            if (v1[i++] != v2[j++])
            return false;
        }
        return true;
        }
    }
    return false;
}
```


即String中equals方法判断相等的步骤是：


1. 若A==B 即是同一个String对象 返回true
2. 若对比对象是String类型则继续，否则返回false
3. 判断A、B长度是否一样，不一样的话返回false
4. 逐个字符比较，若有不相等字符，返回false

这里对equals重新需要注意五点：

1. 自反性：对任意引用值x，x.equals(x)的返回值一定为true.
2. 对称性：对于任何引用值x,y,当且仅当y.equals(x)返回值为true时，x.equals(y)的返回值一定为true;
3. 传递性：如果x.equals(y)=true, y.equals(z)=true,则x.equals(z)=true
4. 一致性：如果参与比较的对象没任何改变，则对象比较的结果也不应该有任何改变
5. 非空性：任何非空的引用值X，x.equals(null)的返回值一定为false

实现高质量equals方法的诀窍：

1. 使用==符号检查“参数是否为这个对象的引用”。如果是，则返回true。这只不过是一种性能优化，如果比较操作有可能很昂贵，就值得这么做。
2. 使用instanceof操作符检查“参数是否为正确的类型”。如果不是，则返回false。一般来说，所谓“正确的类型”是指equals方法所在的那个类。
3. 把参数转换成正确的类型。因为转换之前进行过instanceof测试，所以确保会成功。
4. 对于该类中的每个“关键”域，检查参数中的域是否与该对象中对应的域相匹配。如果这些测试全部成功，则返回true;否则返回false。
5. 当编写完成了equals方法之后，检查“对称性”、“传递性”、“一致性”。

-------
- hashCode
hashCode()方法返回的就是一个数值，从方法的名称上就可以看出，其目的是生成一个hash码。hash码的主要用途就是在对对象进行散列的时候作为key输入，据此很容易推断出，我们需要每个对象的hash码尽可能不同，这样才能保证散列的存取性能。事实上，Object类提供的默认实现确实保证每个对象的hash码不同（在对象的内存地址基础上经过特定算法返回一个hash码）。Java采用了哈希表的原理。哈希（Hash）实际上是个人名，由于他提出一哈希算法的概念，所以就以他的名字命名了。 哈希算法也称为散列算法，是将数据依特定算法直接指定到一个地址上。初学者可以这样理解，hashCode方法实际上返回的就是对象存储的物理地址（实际可能并不是）。

-------
- 散列函数,散列算法,哈希函数。
是一种从任何一种数据中创建小的数字“指纹”的方法。
散列函数将任意长度的二进制值映射为较短的固定长度的二进制值，这个小的二进制值称为哈希值。
好的散列函数在输入域中很少出现散列冲突。
所有散列函数都有如下一个基本特性：

1. 如果a=b，则h(a) = h(b)。
2. 如果a!=b，则h(a)与h(b)可能得到相同的散列值。

Object 的hashCode方法：返回一个int类型

```
    public native int hashCode();
```

-------
- hashCode的作用
想要明白，必须要先知道Java中的集合。　　
总的来说，Java中的集合（Collection）有两类，一类是List，再有一类是Set。前者集合内的元素是有序的，元素可以重复；后者元素无序，但元素不可重复。

那么这里就有一个比较严重的问题了：要想保证元素不重复，可两个元素是否重复应该依据什么来判断呢？

这就是Object.equals方法了。但是，如果每增加一个元素就检查一次，那么当元素很多时，后添加到集合中的元素比较的次数就非常多了。也就是说，如果集合中现在已经有1000个元素，那么第1001个元素加入集合时，它就要调用1000次equals方法。这显然会大大降低效率。
于是，Java采用了哈希表的原理。

这样一来，当集合要添加新的元素时，

先调用这个元素的hashCode方法，就一下子能定位到它应该放置的物理位置上。 如果这个位置上没有元素，它就可以直接存储在这个位置上，不用再进行任何比较了；如果这个位置上已经有元素了，就调用它的equals方法与新元素进行比较，相同的话就不存，不相同就散列其它的地址。所以这里存在一个冲突解决的问题。这样一来实际调用equals方法的次数就大大降低了，几乎只需要一两次。

---------------------
- eqauls方法和hashCode方法关系

Java对于eqauls方法和hashCode方法是这样规定的：

1. 同一对象上多次调用hashCode()方法，总是返回相同的整型值。
2. 如果a.equals(b)，则一定有a.hashCode() 一定等于 b.hashCode()。
3. 如果!a.equals(b)，则a.hashCode() 不一定等于b.hashCode()。此时如果a.hashCode() 总是不等于 b.hashCode()，会提高hashtables的性能。
4. a.hashCode()==b.hashCode() 则 a.equals(b)可真可假
5. a.hashCode()！= b.hashCode() 则 a.equals(b)为假。

上面结论简记：

1. 如果两个对象equals，Java运行时环境会认为他们的hashcode一定相等。
2. 如果两个对象不equals，他们的hashcode有可能相等。
3. 如果两个对象hashcode相等，他们不一定equals。
4. 如果两个对象hashcode不相等，他们一定不equals。

关于这两个方法的重要规范：

- 规范1：若重写equals(Object obj)方法，有必要重写hashcode()方法，确保通过equals(Object obj)方法判断结果为true的两个对象具备相等的hashcode()返回值。说得简单点就是：“如果两个对象相同，那么他们的hashcode应该相等”。不过请注意：这个只是规范，如果你非要写一个类让equals(Object obj)返回true而hashcode()返回两个不相等的值，编译和运行都是不会报错的。不过这样违反了Java规范，程序也就埋下了BUG。
- 规范2：如果equals(Object obj)返回false，即两个对象“不相同”，并不要求对这两个对象调用hashcode()方法得到两个不相同的数。说的简单点就是：“如果两个对象不相同，他们的hashcode可能相同”。


--------------------------
- 为什么覆盖equals时总要覆盖hashCode
 一个很常见的错误根源在于没有覆盖hashCode方法。在每个覆盖了equals方法的类中，也必须覆盖hashCode方法。如果不这样做的话，就会违反Object.hashCode的通用约定，从而导致该类无法结合所有基于散列的集合一起正常运作，这样的集合包括HashMap、HashSet和Hashtable。

1. 在应用程序的执行期间，只要对象的equals方法的比较操作所用到的信息没有被修改，那么对这同一个对象调用多次，hashCode方法都必须始终如一地返回同一个整数。在同一个应用程序的多次执行过程中，每次执行所返回的整数可以不一致。
2. 如果两个对象根据equals()方法比较是相等的，那么调用这两个对象中任意一个对象的hashCode方法都必须产生同样的整数结果。
3. 如果两个对象根据equals()方法比较是不相等的，那么调用这两个对象中任意一个对象的hashCode方法，则不一定要产生相同的整数结果。但是程序员应该知道，给不相等的对象产生截然不同的整数结果，有可能提高散列表的性能。

--------------------------
- 总结：
1、equals方法用于比较对象的内容是否相等（覆盖以后）
2、hashcode方法只有在集合中用到
3、当覆盖了equals方法时，比较对象是否相等将通过覆盖后的equals方法进行比较（判断对象的内容是否相等）。
4、将对象放入到集合中时，首先判断要放入对象的hashcode值与集合中的任意一个元素的hashcode值是否相等，如果不相等直接将该对象放入集合中。如果hashcode值相等，然后再通过equals方法判断要放入对象与集合中的任意一个对象是否相等，如果equals判断不相等，直接将该元素放入到集合中，否则不放入。

- 详情参考: [java中equals，hashcode和==的区别](https://www.cnblogs.com/kexianting/p/8508207.html)

## 1.2 int、char、long各占多少字节数

```
public static void main(String[] args) {
    System.out.println(Byte.SIZE);
    System.out.println(Character.SIZE);
    System.out.println(Short.SIZE);
    System.out.println(Integer.SIZE);
    System.out.println(Float.SIZE);
    System.out.println(Double.SIZE);
    System.out.println(Long.SIZE);
}
```

```
8
16
16
32
32
64
64
```

|type|size|description|
|--|--|--|
|byte|1字节|最小值是 -128（-2^7）；最大值是 127（2^7-1）；|
|boolean|至少1字节|这种类型只作为一种标志来记录 true/false 情况；|
|short|2字节|最小值是 -32768（-2^15）；最大值是 32767（2^15 - 1）；|
|char|2字节|最小值是 \u0000（即为0）；最大值是 \uffff（即为65,535）；|
|int|4字节|最小值是 -2,147,483,648（-2^31）；最大值是 2,147,483,647（2^31 - 1）；|
|float|4字节|单精度浮点数字长32位，尾数长度23，指数长度8,指数偏移量127；|
|long|8字节|最小值是 -9,223,372,036,854,775,808（-2^63）；最大值是 9,223,372,036,854,775,807（2^63 -1）；|
|double|8字节|双精度浮点数字长64位，尾数长度52，指数长度11，指数偏移量1023；|

详情参考: [java中 int、char、long各占多少字节数](https://blog.csdn.net/qq_31615049/article/details/80574551)

## 1.3 int与integer的区别

1. Integer是int的包装类，int则是java的一种基本数据类型
2. Integer变量必须实例化后才能使用，而int变量不需要
3. Integer实际是对象的引用，当new一个Integer时，实际上是生成一个指针指向此对象；而int则是直接存储数据值
4. Integer的默认值是null，int的默认值是0

延伸：
关于Integer和int的比较

**1.由于Integer变量实际上是对一个Integer对象的引用，所以两个通过new生成的Integer变量永远是不相等的（因为new生成的是两个对象，其内存地址不同）。**

```java
Integer i = new Integer(100);
Integer j = new Integer(100);
System.out.print(i == j); //false
```

**2.Integer变量和int变量比较时，只要两个变量的值是向等的，则结果为true（因为包装类Integer和基本数据类型int比较时，java会自动拆包装为int，然后进行比较，实际上就变为两个int变量的比较）**

```java
Integer i = new Integer(100);
int j = 100；
System.out.print(i == j); //true
```

**3.非new生成的Integer变量和new Integer()生成的变量比较时，结果为false。（因为非new生成的Integer变量指向的是java常量池中的对象，而new Integer()生成的变量指向堆中新建的对象，两者在内存中的地址不同）**

```
Integer i = new Integer(100);
Integer j = 100;
System.out.print(i == j); //false
```

**4.对于两个非new生成的Integer对象，进行比较时，如果两个变量的值在区间-128到127之间，则比较结果为true，如果两个变量的值不在此区间，则比较结果为false**

```
Integer i = 100;
Integer j = 100;
System.out.print(i == j); //true
Integer i = 128;
Integer j = 128;
System.out.print(i == j); //false
```

对于第4条的原因：
java在编译Integer i = 100 ;时，会翻译成为Integer i = Integer.valueOf(100)；，而java API中对Integer类型的valueOf的定义如下：

```java
 public static Integer valueOf(int i){
     assert IntegerCache.high >= 127;
     if (i >= IntegerCache.low && i <= IntegerCache.high){
         return IntegerCache.cache[i + (-IntegerCache.low)];
     }
     return new Integer(i);
}
```

java对于-128到127之间的数，会进行缓存，Integer i = 127时，会将127进行缓存，下次再写Integer j = 127时，就会直接从缓存中取，就不会new了

[Java里面的int和Integer的区别](https://www.cnblogs.com/slhs/p/7710063.html)

## 1.4 谈谈对java多态的理解

运行时多态性是面向对象程序设计代码重用的一个最强大机制，Java多态性的概念也可以被说成“一个接口，多个方法”。Java实现运行时多态性的基础是动态方法调度，它是一种在运行时而不是在编译期调用重载方法的机制。

方法的重写Overriding和重载Overloading是Java多态性的不同表现。重写Overriding是父类与子类之间多态性的一种表现，重载Overloading是一个类中多态性的一种表现。如果在子类中定义某方法与其父类有相同的名称和参数，我们说该方法被重写(Overriding)。子类的对象使用这个方法时，将调用子类中的定义，对它而言，父类中的定义如同被“屏蔽”了。如果在一个类中定义了多个同名的方法，它们或有不同的参数个数或有不同的参数类型，则称为方法的重载(Overloading)。Overloaded的方法是可以改变返回值的类型。方法的重写Overriding和重载Overloading是Java多态性的不同表现。重写Overriding是父类与子类之间多态性的一种表现，重载Overloading是一个类中Java多态性的一种表现。如果在子类中定义某方法与其父类有相同的名称和参数，我们说该方法被重写 (Overriding)。子类的对象使用这个方法时，将调用子类中的定义，对它而言，父类中的定义如同被“屏蔽”了。如果在一个类中定义了多个同名的方法，它们或有不同的参数个数或有不同的参数类型，则称为方法的重载(Overloading)。Overloaded的方法是可以改变返回值的类型。

当超类对象引用变量引用子类对象时，被引用对象的类型而不是引用变量的类型决定了调用谁的成员方法，但是这个被调用的方法必须是在超类中定义过的，也就是说被子类覆盖的方法。 （但是如果强制把超类转换成子类的话，就可以调用子类中新添加而超类没有的方法了。）

详情参考: [关于多态性的理解](https://blog.csdn.net/kuaisuzhuceh/article/details/46726281)

## 1.5 String、StringBuffer、StringBuilder区别

**可变性**

String类中使用字符数组保存字符串，`private　final　char　value[]`，所以string对象是不可变的。StringBuilder与StringBuffer都继承自AbstractStringBuilder类，在AbstractStringBuilder中也是使用字符数组保存字符串，char[]value，这两种对象都是可变的。

**线程安全性**

String中的对象是不可变的，也就可以理解为常量，线程安全。AbstractStringBuilder是StringBuilder与StringBuffer的公共父类，定义了一些字符串的基本操作，如expandCapacity、append、insert、indexOf等公共方法。StringBuffer对方法加了同步锁或者对调用的方法加了同步锁，所以是线程安全的。StringBuilder并没有对方法进行加同步锁，所以是非线程安全的。

**性能**

每次对String类型进行改变的时候，都会生成一个新的String对象，然后将指针指向新的String 对象。StringBuffer每次都会对StringBuffer对象本身进行操作，而不是生成新的对象并改变对象引用。相同情况下使用StirngBuilder 相比使用StringBuffer 仅能获得10%~15% 左右的性能提升，但却要冒多线程不安全的风险。
**对于三者使用的总结：**
如果要操作少量的数据用 = String
单线程操作字符串缓冲区 下操作大量数据 = StringBuilder
多线程操作字符串缓冲区 下操作大量数据 = StringBuffer

## 1.6 什么是内部类？内部类的作用

**内部类基础**

在Java中，可以将一个类定义在另一个类里面或者一个方法里面，这样的类称为内部类。广泛意义上的内部类一般来说包括这四种：成员内部类、局部内部类、匿名内部类和静态内部类。下面就先来了解一下这四种内部类的用法。

**1.成员内部类**
成员内部类是最普通的内部类，它的定义为位于另一个类的内部，形如下面的形式：

```java
class Circle {
    double radius = 0;
    public Circle(double radius) {
        this.radius = radius;
    }
    class Draw {     //内部类
        public void drawSahpe() {
            System.out.println("drawshape");
        }
    }
}
```

这样看起来，类Draw像是类Circle的一个成员，Circle称为外部类。成员内部类可以无条件访问外部类的所有成员属性和成员方法（包括private成员和静态成员）。

```java
class Circle {
    private double radius = 0;
    public static int count =1;
    public Circle(double radius) {
        this.radius = radius;
    }

    class Draw {     //内部类
        public void drawSahpe() {
            System.out.println(radius);  //外部类的private成员
            System.out.println(count);   //外部类的静态成员
        }
    }
}
```

不过要注意的是，当成员内部类拥有和外部类同名的成员变量或者方法时，会发生隐藏现象，即默认情况下访问的是成员内部类的成员。如果要访问外部类的同名成员，需要以下面的形式进行访问：

```
外部类.this.成员变量
外部类.this.成员方法
```

虽然成员内部类可以无条件地访问外部类的成员，而外部类想访问成员内部类的成员却不是这么随心所欲了。在外部类中如果要访问成员内部类的成员，必须先创建一个成员内部类的对象，再通过指向这个对象的引用来访问：

```
class Circle {
    private double radius = 0;

    public Circle(double radius) {
        this.radius = radius;
        getDrawInstance().drawSahpe();   //必须先创建成员内部类的对象，再进行访问
    }

    private Draw getDrawInstance() {
        return new Draw();
    }

    class Draw {     //内部类
        public void drawSahpe() {
            System.out.println(radius);  //外部类的private成员
        }
    }
}
```

成员内部类是依附外部类而存在的，也就是说，如果要创建成员内部类的对象，前提是必须存在一个外部类的对象。创建成员内部类对象的一般方式如下：

```java
public class Test {
    public static void main(String[] args)  {
        //第一种方式：
        Outter outter = new Outter();
        Outter.Inner inner = outter.new Inner();  //必须通过Outter对象来创建

        //第二种方式：
        Outter.Inner inner1 = outter.getInnerInstance();
    }
}

class Outter {
    private Inner inner = null;
    public Outter() {

    }

    public Inner getInnerInstance() {
        if(inner == null)
            inner = new Inner();
        return inner;
    }

    class Inner {
        public Inner() {

        }
    }
}
```

内部类可以拥有private访问权限、protected访问权限、public访问权限及包访问权限。比如上面的例子，如果成员内部类Inner用private修饰，则只能在外部类的内部访问，如果用public修饰，则任何地方都能访问；如果用protected修饰，则只能在同一个包下或者继承外部类的情况下访问；如果是默认访问权限，则只能在同一个包下访问。这一点和外部类有一点不一样，外部类只能被public和包访问两种权限修饰。我个人是这么理解的，由于成员内部类看起来像是外部类的一个成员，所以可以像类的成员一样拥有多种权限修饰。

**2.局部内部类**

局部内部类是定义在一个方法或者一个作用域里面的类，它和成员内部类的区别在于局部内部类的访问仅限于方法内或者该作用域内。

```java
class People{
    public People() {

    }
}

class Man{
    public Man(){
    }
    public People getWoman(){
        class Woman extends People{   //局部内部类
            int age =0;
        }
        return new Woman();
    }
}
```
注意，局部内部类就像是方法里面的一个局部变量一样，是不能有public、protected、private以及static修饰符的。

**3.匿名内部类**

匿名内部类应该是平时我们编写代码时用得最多的，在编写事件监听的代码时使用匿名内部类不但方便，而且使代码更加容易维护。下面这段代码是一段Android事件监听代码：

```java
scan_bt.setOnClickListener(new OnClickListener() {
    @Override
    public void onClick(View v) {
        // TODO Auto-generated method stub

    }
});

history_bt.setOnClickListener(new OnClickListener() {
    @Override
    public void onClick(View v) {
        // TODO Auto-generated method stub
    }
});
```
这段代码为两个按钮设置监听器，这里面就使用了匿名内部类。这段代码中的：

```
new OnClickListener() {
    @Override
    public void onClick(View v) {
        // TODO Auto-generated method stub
    }
}
```

就是匿名内部类的使用。代码中需要给按钮设置监听器对象，使用匿名内部类能够在实现父类或者接口中的方法情况下同时产生一个相应的对象，但是前提是这个父类或者接口必须先存在才能这样使用。当然像下面这种写法也是可以的，跟上面使用匿名内部类达到效果相同。

```java
private void setListener()
{
    scan_bt.setOnClickListener(new Listener1());
    history_bt.setOnClickListener(new Listener2());
}

class Listener1 implements View.OnClickListener{
    @Override
    public void onClick(View v) {
    // TODO Auto-generated method stub

    }
}

class Listener2 implements View.OnClickListener{
    @Override
    public void onClick(View v) {
    // TODO Auto-generated method stub
    }
}
```

这种写法虽然能达到一样的效果，但是既冗长又难以维护，所以一般使用匿名内部类的方法来编写事件监听代码。同样的，匿名内部类也是不能有访问修饰符和static修饰符的。

匿名内部类是唯一一种没有构造器的类。正因为其没有构造器，所以匿名内部类的使用范围非常有限，大部分匿名内部类用于接口回调。匿名内部类在编译的时候由系统自动起名为Outter$1.class。一般来说，匿名内部类用于继承其他类或是实现接口，并不需要增加额外的方法，只是对继承方法的实现或是重写。

**4.静态内部类**

静态内部类也是定义在另一个类里面的类，只不过在类的前面多了一个关键字static。静态内部类是不需要依赖于外部类的，这点和类的静态成员属性有点类似，并且它不能使用外部类的非static成员变量或者方法，这点很好理解，因为在没有外部类的对象的情况下，可以创建静态内部类的对象，如果允许访问外部类的非static成员就会产生矛盾，因为外部类的非static成员必须依附于具体的对象。

```java
public class Test {
    public static void main(String[] args)  {
        Outter.Inner inner = new Outter.Inner();
    }
}

class Outter {
    public Outter() {

    }

    static class Inner {
        public Inner() {

        }
    }
}
```

**深入理解内部类**

**1.为什么成员内部类可以无条件访问外部类的成员？**
在此之前，我们已经讨论过了成员内部类可以无条件访问外部类的成员，那具体究竟是如何实现的呢？下面通过反编译字节码文件看看究竟。事实上，编译器在进行编译的时候，会将成员内部类单独编译成一个字节码文件，下面是Outter.java的代码：

```java
public class Outter {
    private Inner inner = null;
    public Outter() {

    }
    public Inner getInnerInstance() {
        if(inner == null)
            inner = new Inner();
        return inner;
    }
    protected class Inner {
        public Inner() {
        }
    }
}
```

编译之后，出现了两个字节码文件：

```
Outter$Inner.class
Outter.class
```

反编译Outter$Inner.class文件得到下面信息：

```
 bill@ThinkPad:~/test$ javap -v Outter\$Inner.class
Classfile /home/bill/test/Outter$Inner.class
  Last modified Feb 27, 2019; size 304 bytes
  MD5 checksum 732ba89287828251572200e940699e56
  Compiled from "Outter.java"
public class Outter$Inner
  minor version: 0
  major version: 52
  flags: ACC_PUBLIC, ACC_SUPER
Constant pool:
   #1 = Fieldref           #3.#13         // Outter$Inner.this$0:LOutter;
   #2 = Methodref          #4.#14         // java/lang/Object."<init>":()V
   #3 = Class              #16            // Outter$Inner
   #4 = Class              #19            // java/lang/Object
   #5 = Utf8               this$0
   #6 = Utf8               LOutter;
   #7 = Utf8               <init>
   #8 = Utf8               (LOutter;)V
   #9 = Utf8               Code
  #10 = Utf8               LineNumberTable
  #11 = Utf8               SourceFile
  #12 = Utf8               Outter.java
  #13 = NameAndType        #5:#6          // this$0:LOutter;
  #14 = NameAndType        #7:#20         // "<init>":()V
  #15 = Class              #21            // Outter
  #16 = Utf8               Outter$Inner
  #17 = Utf8               Inner
  #18 = Utf8               InnerClasses
  #19 = Utf8               java/lang/Object
  #20 = Utf8               ()V
  #21 = Utf8               Outter
{
  final Outter this$0;
    descriptor: LOutter;
    flags: ACC_FINAL, ACC_SYNTHETIC

  public Outter$Inner(Outter);
    descriptor: (LOutter;)V
    flags: ACC_PUBLIC
    Code:
      stack=2, locals=2, args_size=2
         0: aload_0
         1: aload_1
         2: putfield      #1                  // Field this$0:LOutter;
         5: aload_0
         6: invokespecial #2                  // Method java/lang/Object."<init>":()V
         9: return
      LineNumberTable:
        line 14: 0
        line 16: 9
}
SourceFile: "Outter.java"
InnerClasses:
     protected #17= #3 of #15; //Inner=class Outter$Inner of class Outter

```

第33行的内容：

```
final Outter this$0;
```

这行是一个指向外部类对象的指针，看到这里想必大家豁然开朗了。也就是说编译器会默认为成员内部类添加了一个指向外部类对象的引用，那么这个引用是如何赋初值的呢？下面接着看内部类的构造器：

```
public Outter$Inner(Outter);
```

从这里可以看出，虽然我们在定义的内部类的构造器是无参构造器，编译器还是会默认添加一个参数，该参数的类型为指向外部类对象的一个引用，所以成员内部类中的Outter this&0 指针便指向了外部类对象，因此可以在成员内部类中随意访问外部类的成员。从这里也间接说明了成员内部类是依赖于外部类的，如果没有创建外部类的对象，则无法对Outter this&0引用进行初始化赋值，也就无法创建成员内部类的对象了。

**2.为什么局部内部类和匿名内部类只能访问局部final变量？**

想必这个问题也曾经困扰过很多人，在讨论这个问题之前，先看下面这段代码：

```java
public class Test {
    public static void main(String[] args)  {
    }
    public void test(final int b) {
        final int a = 10;
        new Thread(){
            public void run() {
                System.out.println(a);
                System.out.println(b);
            };
        }.start();
    }
}
```

这段代码会被编译成两个class文件：

```
Test.class
Test$1.class
```
默认情况下，编译器会为匿名内部类和局部内部类起名为Outterx.class（x为正整数）。

上段代码中，如果把变量a和b前面的任一个final去掉，这段代码都编译不过。我们先考虑这样一个问题：

当test方法执行完毕之后，变量a的生命周期就结束了，而此时Thread对象的生命周期很可能还没有结束，那么在Thread的run方法中继续访问变量a就变成不可能了，但是又要实现这样的效果，怎么办呢？Java采用了 复制  的手段来解决这个问题。将这段代码的字节码反编译可以得到下面的内容：

```
...
public void run();
    descriptor: ()V
    flags: ACC_PUBLIC
    Code:
      stack=2, locals=1, args_size=1
         0: getstatic     #4                  // Field java/lang/System.out:Ljava/io/PrintStream;
         3: bipush        10
         5: invokevirtual #5                  // Method java/io/PrintStream.println:(I)V
         8: getstatic     #4                  // Field java/lang/System.out:Ljava/io/PrintStream;
        11: aload_0
        12: getfield      #2                  // Field val$b:I
        15: invokevirtual #5                  // Method java/io/PrintStream.println:(I)V
        18: return
      LineNumberTable:
        line 8: 0
        line 9: 8
        line 10: 18
...
```

我们看到在run方法中有一条指令：

```
3: bipush        10
```

这条指令表示将操作数10压栈，表示使用的是一个本地局部变量。这个过程是在编译期间由编译器默认进行，如果这个变量的值在编译期间可以确定，则编译器默认会在匿名内部类（局部内部类）的常量池中添加一个内容相等的字面量或直接将相应的字节码嵌入到执行字节码中。这样一来，匿名内部类使用的变量是另一个局部变量，只不过值和方法中局部变量的值相等，因此和方法中的局部变量完全独立开。

下面再看一个例子：

```
{
  final int val$a;
    descriptor: I
    flags: ACC_FINAL, ACC_SYNTHETIC

  final Test this$0;
    descriptor: LTest;
    flags: ACC_FINAL, ACC_SYNTHETIC

  Test$1(Test, int);
    descriptor: (LTest;I)V
    flags:
    Code:
      stack=2, locals=3, args_size=3
         0: aload_0
         1: aload_1
         2: putfield      #1                  // Field this$0:LTest;
         5: aload_0
         6: iload_2
         7: putfield      #2                  // Field val$a:I
        10: aload_0
        11: invokespecial #3                  // Method java/lang/Thread."<init>":()V
        14: return
      LineNumberTable:
        line 7: 0

  public void run();
    descriptor: ()V
    flags: ACC_PUBLIC
    Code:
      stack=2, locals=1, args_size=1
         0: getstatic     #4                  // Field java/lang/System.out:Ljava/io/PrintStream;
         3: aload_0
         4: getfield      #2                  // Field val$a:I
         7: invokevirtual #5                  // Method java/io/PrintStream.println:(I)V
        10: return
      LineNumberTable:
        line 9: 0
        line 10: 10
}
SourceFile: "Test.java"
EnclosingMethod: #21.#22                // Test.test
InnerClasses:
     #6; //class Test$1

```


我们看到匿名内部类Test$1的构造器含有两个参数，一个是指向外部类对象的引用，一个是int型变量，很显然，这里是将变量test方法中的形参a以参数的形式传进来对匿名内部类中的拷贝（变量a的拷贝）进行赋值初始化。

**也就说如果局部变量的值在编译期间就可以确定，则直接在匿名内部里面创建一个拷贝。如果局部变量的值无法在编译期间确定，则通过构造器传参的方式来对拷贝进行初始化赋值。**

从上面可以看出，在run方法中访问的变量a根本就不是test方法中的局部变量a。这样一来就解决了前面所说的 生命周期不一致的问题。但是新的问题又来了，既然在run方法中访问的变量a和test方法中的变量a不是同一个变量，当在run方法中改变变量a的值的话，会出现什么情况？

对，会造成数据不一致性，这样就达不到原本的意图和要求。为了解决这个问题，java编译器就限定必须将变量a限制为final变量，不允许对变量a进行更改（对于引用类型的变量，是不允许指向新的对象），这样数据不一致性的问题就得以解决了。

到这里，想必大家应该清楚为何方法中的局部变量和形参都必须用final进行限定了。

**3.静态内部类有特殊的地方吗？**

从前面可以知道，静态内部类是不依赖于外部类的，也就说可以在不创建外部类对象的情况下创建内部类的对象。另外，静态内部类是不持有指向外部类对象的引用的，这个读者可以自己尝试反编译class文件看一下就知道了，是没有Outter this&0引用的。

```java
public class Outter {
    private Inner inner = null;
    public Outter() {

    }
    public Inner getInnerInstance() {
        if(inner == null)
            inner = new Inner();
        return inner;
    }
    static class Inner {
        public Inner() {
        }
    }
}
```

```
bill@ThinkPad:~/test$ javap -v Outter\$Inner.class
Classfile /home/bill/test/Outter$Inner.class
  Last modified Feb 27, 2019; size 247 bytes
  MD5 checksum 49f1ac59bf30823652c62cfb3807f21e
  Compiled from "Outter.java"
class Outter$Inner
  minor version: 0
  major version: 52
  flags: ACC_SUPER
Constant pool:
   #1 = Methodref          #3.#10         // java/lang/Object."<init>":()V
   #2 = Class              #12            // Outter$Inner
   #3 = Class              #15            // java/lang/Object
   #4 = Utf8               <init>
   #5 = Utf8               ()V
   #6 = Utf8               Code
   #7 = Utf8               LineNumberTable
   #8 = Utf8               SourceFile
   #9 = Utf8               Outter.java
  #10 = NameAndType        #4:#5          // "<init>":()V
  #11 = Class              #16            // Outter
  #12 = Utf8               Outter$Inner
  #13 = Utf8               Inner
  #14 = Utf8               InnerClasses
  #15 = Utf8               java/lang/Object
  #16 = Utf8               Outter
{
  public Outter$Inner();
    descriptor: ()V
    flags: ACC_PUBLIC
    Code:
      stack=1, locals=1, args_size=1
         0: aload_0
         1: invokespecial #1                  // Method java/lang/Object."<init>":()V
         4: return
      LineNumberTable:
        line 12: 0
        line 13: 4
}
SourceFile: "Outter.java"
InnerClasses:
     static #13= #2 of #11; //Inner=class Outter$Inner of class Outter

```

**内部类的使用场景和好处**

为什么在Java中需要内部类？总结一下主要有以下四点：
1. 每个内部类都能独立的继承一个接口的实现，所以无论外部类是否已经继承了某个(接口的)实现，对于内部类都没有影响。内部类使得多继承的解决方案变得完整，
2. 方便将存在一定逻辑关系的类组织在一起，又可以对外界隐藏。
3. 方便编写事件驱动程序
4. 方便编写线程代码
个人觉得第一点是最重要的原因之一，内部类的存在使得Java的多继承机制变得更加完善。

四.常见的与内部类相关的笔试面试题

 1.根据注释填写(1)，(2)，(3)处的代码


```java
public class Solution{
    public static void main(String[] args){
        // 初始化Bean1
        //(1)
        bean1.I++;
        // 初始化Bean2
        //(2)
        bean2.J++;
        //初始化Bean3
        //(3)
        bean3.k++;
    }
    class Bean1{
        public int I = 0;
    }
    static class Bean2{
        public int J = 0;
    }
}

class Bean{
    class Bean3{
        public int k = 0;
    }
}
```

答案:

```java
public class Solution{
    public static void main(String[] args){
        // 初始化Bean1
        //(1)
        Solution mySolution = new Solution();
        Bean1 bean1 = mySolution.new Bean1();
        bean1.I++;
        // 初始化Bean2
        //(2)

        Bean2 bean2 = new Solution.Bean2();

        bean2.J++;
        //初始化Bean3
        //(3)
        Bean bean = new Bean();
        Bean.Bean3 bean3 = bean.new Bean3();
        bean3.k++;
    }
    class Bean1{
        public int I = 0;
    }

    static class Bean2{
        public int J = 0;
    }
}

class Bean{
    class Bean3{
        public int k = 0;
    }
}
```

从前面可知，对于成员内部类，必须先产生外部类的实例化对象，才能产生内部类的实例化对象。而静态内部类不用产生外部类的实例化对象即可产生内部类的实例化对象。

创建静态内部类对象的一般形式为：
**外部类类名.内部类类名 xxx = new 外部类类名.内部类类名()**

创建成员内部类对象的一般形式为：
**外部类类名.内部类类名 xxx = 外部类对象名.new 内部类类名()**

2.下面这段代码的输出结果是什么？

```java
public class Test {
    public static void main(String[] args)  {
        Outter outter = new Outter();
        outter.new Inner().print();
    }
}


class Outter
{
    private int a = 1;
    class Inner {
        private int a = 2;
        public void print() {
            int a = 3;
            System.out.println("局部变量：" + a);
            System.out.println("内部类变量：" + this.a);
            System.out.println("外部类变量：" + Outter.this.a);
        }
    }
}
```

```
3
2
1
```

最后补充一点知识：关于成员内部类的继承问题。一般来说，内部类是很少用来作为继承用的。但是当用来继承的话，要注意两点：

1. 成员内部类的引用方式必须为 Outter.Inner.
2. 构造器中必须有指向外部类对象的引用，并通过这个引用调用super()。这段代码摘自《Java编程思想》

```java
class WithInner {
    class Inner{
    }
}
class InheritInner extends WithInner.Inner {

    // InheritInner() 是不能通过编译的，一定要加上形参
    InheritInner(WithInner wi) {
        wi.super(); //必须有这句调用
    }
    public static void main(String[] args) {
        WithInner wi = new WithInner();
        InheritInner obj = new InheritInner(wi);
    }
}
```

详细参照: [Java内部类详解](https://www.cnblogs.com/dolphin0520/p/3811445.html)



