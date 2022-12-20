---
layout:     post
title:      "Android 强弱指针简析"
summary:    '"Android Smart Pointer Analysis"'
date:       2019-05-15 10:53:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-05-15.jpg"
catalog: true
tags:
    - android
    - smart pointer
---


<!-- vim-markdown-toc GFM -->

* [1. 背景](#1-背景)
* [2. LightRefBase 轻量级的引用计数](#2-lightrefbase-轻量级的引用计数)
* [3. RefBase 目标对象基类](#3-refbase-目标对象基类)
* [4. wp 弱指针](#4-wp-弱指针)
* [5. sp 强指针](#5-sp-强指针)

<!-- vim-markdown-toc -->

# 1. 背景

Android中的Native层代码是使用C++来实现的，一旦涉及C++，就意味着不像Java可以实现自动的垃圾回收机制，不需要操心内存方面的问题。尤其是C++中的指针问题，一旦忘记回收，就可能导致内存泄露问题。一般指针问题归纳为如下几种:

1. 指针未初始化
2. 指针指向的对象未及时销毁
3. 野指针

指针未初始化会导致空指针问题，导致程序崩溃;指针假如在new了对象后，未及时进行销毁，可能导致内存泄漏;假如指针在销毁后，未指向Null对象，可能在后续第三方调用时误认为是存在对象，导致未知行为的错误。智能指针的出现就是为了解决上述问题的，本文会以代码形式深入去探究智能指针的实现和使用方式,基于Android P代码进行分析。

# 2. LightRefBase 轻量级的引用计数

LightRefBase可谓实现了一个简单的以引用计数管理内存对象的智能指针。当对象的引用计数为0时，就会主动进行销毁对象，在Android中也有小范围的使用。其实现如下:

```c++
//system/core/libutils/include/utils/LightRefBase.h
template <class T>
class LightRefBase
{
public:
    inline LightRefBase() : mCount(0) { }
    inline void incStrong(__attribute__((unused)) const void* id) const {
        mCount.fetch_add(1, std::memory_order_relaxed);
    }
    inline void decStrong(__attribute__((unused)) const void* id) const {
        if (mCount.fetch_sub(1, std::memory_order_release) == 1) {
            std::atomic_thread_fence(std::memory_order_acquire);
            delete static_cast<const T*>(this);
        }
    }
    //! DEBUGGING ONLY: Get current strong ref count.
    inline int32_t getStrongCount() const {
        return mCount.load(std::memory_order_relaxed);
    }

    typedef LightRefBase<T> basetype;

protected:
    inline ~LightRefBase() { }

private:
    friend class ReferenceMover;
    inline static void renameRefs(size_t /*n*/, const ReferenceRenamer& /*renamer*/) { }
    inline static void renameRefId(T* /*ref*/, const void* /*old_id*/ , const void* /*new_id*/) { }

private:
    //atomic类型的mCount进行引用
    mutable std::atomic<int32_t> mCount;
};
```

简单的总结LightRefbase的实现:

1.LightRefBase核心使用了引用计数来控制对象的生命周期，关键在于对atomic类型的mCount记录对象被引用的次数。在初始化时，mCount初始化为0。

```c++
inline LightRefBase() : mCount(0) { }
```

如果需要改动mCount的值，只能通过incStrong或者decStrong进行增删，也并没有实现类似重载等方法。可见这个对象的轻量级程度。

2.mCount为atomic类型，atomic是C++11的新特性，能够对atomic类型的对象实现多线程同步的访问。LightRefBase这里使用atomic引用计数，就可以省去许多加锁解锁的操作。其中`fetch_add/fetch_sub`是先返回值，再进行自增自减。

3.引用计数涉及c++11的内存模型，其中incStrong时使用`memory_order_relaxed`,即没有顺序一致性的要求，同一个线程会按照happens-before原则，但不同线程执行关系是任意的。这里可以看出多个线程调用incStrong时，不会去强求一定要按照顺序一致性增加引用计数。 而decStrong使用了release,acquire模型，并使用`atomic_thread_fence`保证有序性。特殊情况当引用计数为1时，有多个线程调用了decStrong，使用release,acquire可以保证其余线程能够及时更新到mCount的值，避免发生race。

```c++
inline void decStrong(__attribute__((unused)) const void* id) const {
   if (mCount.fetch_sub(1, std::memory_order_release) == 1) {
       std::atomic_thread_fence(std::memory_order_acquire);
       delete static_cast<const T*>(this);
   }
}
```

如需要深入理解c++11中的`memory_order`可以参考如下链接:

[1.如何理解 C++11 的六种 memory order？](https://www.zhihu.com/question/24301047)

[2.C++ 多线程与内存模型资料汇](https://github.com/forhappy/Cplusplus-Concurrency-In-Practice/blob/master/zh/chapter8-Memory-Model/web-resources.md)

Android P中还多引入了一个wrapper类VirtualLightRefBase,其析构函数被定义为纯虚函数:


```c++
class VirtualLightRefBase : public LightRefBase<VirtualLightRefBase> {
public:
    virtual ~VirtualLightRefBase() = default;
};
```

引入wrapper类的目的，是为了在多态的情境下，基类指针指向子类，当删除基类指针时，在调用基类析构函数后，保证能够调用子类的析构函数。假如不将析构函数声明为虚函数，就不会调用子类的析构函数。由此可见VirtualLightRefBase用于多态的情景中。

# 3. RefBase 目标对象基类

无论是使用弱指针还是强指针的对象，都需要继承RefBase类，RefBase的实现如下:

```c++
//system/core/libutils/RefBase.cpp
class RefBase
{
public:
            void            incStrong(const void* id) const;
            void            decStrong(const void* id) const;
            void            forceIncStrong(const void* id) const;
            int32_t         getStrongCount() const;

    class weakref_type
    {
    public:
        RefBase*            refBase() const;
        void                incWeak(const void* id);
        void                decWeak(const void* id);
        bool                attemptIncStrong(const void* id);
    };
            weakref_type*   createWeak(const void* id) const;
            weakref_type*   getWeakRefs() const;
    typedef RefBase basetype;

protected:
                            RefBase();
    virtual                 ~RefBase();
    enum {
        OBJECT_LIFETIME_STRONG  = 0x0000,
        OBJECT_LIFETIME_WEAK    = 0x0001,
        OBJECT_LIFETIME_MASK    = 0x0001
    };

            void            extendObjectLifetime(int32_t mode);
    enum {
        FIRST_INC_STRONG = 0x0001
    };

    virtual void            onFirstRef();
    virtual void            onLastStrongRef(const void* id);
    virtual bool            onIncStrongAttempted(uint32_t flags, const void* id);
    virtual void            onLastWeakRef(const void* id);

private:
    friend class ReferenceMover;
    static void moveReferences(void* d, void const* s, size_t n,
            const ReferenceConverterBase& caster);

private:
    friend class weakref_type;
    class weakref_impl;
                            RefBase(const RefBase& o);
            RefBase&        operator=(const RefBase& o);
        weakref_impl* const mRefs;
};
```

RefBase中定义了一个内部类`weakref_type`,看方法而言似乎是与弱指针相关，且有一个特殊的私有成员mRefs，其类型为`weakref_impl`,为`weakref_type`的子类。当继承于RefBase的对象初始化时，即会调用到父类的构造函数,并新建一个`weakref_impl`对象，并用mRefs指针指向该对象。

```c++
RefBase::RefBase()
    : mRefs(new weakref_impl(this))
{
}
```
具体RefBase的细节在后续与强弱指针的内容一同分析。

# 4. wp 弱指针

弱指针的本意是为了解决指针互相引用的情景，假如有两个对象，其关系为父子关系，且指针互相指向对方，那么这两个对象最终都不会被释放，与死锁的情况很相似。但如果引入强弱指针概念后，并规定父类指向子类的为强指针，而子类指向父类的使用弱指针。那么只要强指针引用计数为0时，无论弱指针的引用计数是否为0，都可以删除对象。

![](/img/bill/in-posts/2019-05-15/wp.png)


wp的关系图如上，首先对象如果需要使用wp管理，需要首先继承RefBase类。一般弱指针的用法如下:

```c++
    wp<type> object = new type();
```

wp的维护这两个特殊的变量`m_ptr`以及`m_refs`,前者为泛型指针，指向继承于RefBase的对象，后者为`weakref_type`指向的应当是新建RefBase时创建的`weakref_impl`对象。

```c++
    T*              m_ptr;
    weakref_type*   m_refs;
```

其中一般的无参方法，`m_ptr`默认指向0:

```c++
//system/core/libutils/include/utils/RefBase.h
inline wp() : m_ptr(0) { }
```

带参数的可以传入对象的类型，wp，sp等，其中直接传对象的实现中，构造时将`m_ptr`指向该对象，并调用RefBase的方法createWeak来返回`weakref_type`类型的对象，用`m_refs`指向该对象。
```c++
template<typename T>
wp<T>::wp(T* other)
    : m_ptr(other)
{
    if (other) m_refs = other->createWeak(this);
}
```

createWeak实质是调用RefBase的mRefs指向的对象的incWeak接口,并返回该对象，使得wp中也能够获取RefBase的`weakref_impl`对象。
```c++
RefBase::weakref_type* RefBase::createWeak(const void* id) const
{
    mRefs->incWeak(id);
    return mRefs;
}
```

incWeak中，也是先将`weakref_type`下溯到子类的`weakref_impl`，这个转换是不安全的，需要程序员确保其安全性，并调用addWeakRef。最后一步将`weakref_impl`的mWeak自增，且内存模型为`memory_order_relaxed`。
```c++
void RefBase::weakref_type::incWeak(const void* id)
{
    weakref_impl* const impl = static_cast<weakref_impl*>(this);
    impl->addWeakRef(id);
    const int32_t c __unused = impl->mWeak.fetch_add(1,
            std::memory_order_relaxed);
}
```

先回过头来看`weakref_impl`的定义:

```c++
class RefBase::weakref_impl : public RefBase::weakref_type
{
public:
    std::atomic<int32_t>    mStrong; //强引用计数
    std::atomic<int32_t>    mWeak; //弱引用计数
    RefBase* const          mBase; //指向目标对象
    std::atomic<int32_t>    mFlags;//用以确定对象声明周期，默认为OBJECT_LIFETIME_STRONG
    ...
}

weakref_impl(RefBase* base)
        : mStrong(INITIAL_STRONG_VALUE)
        , mWeak(0)
        , mBase(base)
        , mFlags(0)
        , mStrongRefs(NULL)
        , mWeakRefs(NULL)
        , mTrackEnabled(!!DEBUG_REFS_ENABLED_BY_DEFAULT)
        , mRetain(false)
    {
    }
... 
```

当前看，每当wp指向新对象时，mWeak就会增加1，即为弱指针的引用计数。猜想mStrong一定也是关于强指针的引用计数。

addWeakRef调用了addRef，但其实质没有做什么工作，至此可以认为wp新建时仅仅是增加了引用技术罢了。
```c++
void addWeakRef(const void* id) {
    addRef(&mWeakRefs, id, mWeak.load(std::memory_order_relaxed));
}
```

与强指针sp相比，弱指针并不能够直接的访问目标对象，而需要通过promote进行升级到强指针后才可。promote中先确保`m_ptr`对象存在，再通过attemptIncStrong尝试升级强指针。
```c++
template<typename T>
sp<T> wp<T>::promote() const
{
    sp<T> result;
    if (m_ptr && m_refs->attemptIncStrong(&result)) {
        result.set_pointer(m_ptr);
    }
    return result;
}
```

attemptIncStrong
```c++
bool RefBase::weakref_type::attemptIncStrong(const void* id)
{
    //增加弱引用计数
    incWeak(id);
    //获取当前强引用计数 
    weakref_impl* const impl = static_cast<weakref_impl*>(this);
    int32_t curCount = impl->mStrong.load(std::memory_order_relaxed);
    //假如当前强引用技术大于0，通过compare_exchange_weak自增，即mStrong自增了1. 
    //这种情况即该对象是存在强指针指向的。
    while (curCount > 0 && curCount != INITIAL_STRONG_VALUE) {
        if (impl->mStrong.compare_exchange_weak(curCount, curCount+1,
                std::memory_order_relaxed)) {
            break;
        }
    }
   //当这种情况是该对象没有强指针指向的。 
   if (curCount <= 0 || curCount == INITIAL_STRONG_VALUE) {
        //flags用来确定
        int32_t flags = impl->mFlags.load(std::memory_order_relaxed);
        //此时生命周期被强引用影响。
        if ((flags&OBJECT_LIFETIME_MASK) == OBJECT_LIFETIME_STRONG) {
            if (curCount <= 0) {
                //此时强引用计数为0，即该对象不存在，需要自减弱引用计数，并返回失败 
                decWeak(id);
                return false;
            }
            //此时是强引用计数为INITIAL_STRONG_VALUE，即未被强指针指向过 
            while (curCount > 0) {
                //强指针自增
                if (impl->mStrong.compare_exchange_weak(curCount, curCount+1,
                        std::memory_order_relaxed)) {
                    break;
                }
            }
            //处理失败的情况
            if (curCount <= 0) {
                decWeak(id);
                return false;
            }
        } else {
            //此时生命周期被弱引用计数影响，调用onIncStrongAttempted确认能否升级为强指针。 
            if (!impl->mBase->onIncStrongAttempted(FIRST_INC_STRONG, id)) {
                decWeak(id);
                return false;
            }
            //强指针自增
            curCount = impl->mStrong.fetch_add(1, std::memory_order_relaxed);
            //调用onLastStrongRef进行后处理 
            if (curCount != 0 && curCount != INITIAL_STRONG_VALUE) {
                impl->mBase->onLastStrongRef(id);
            }
        }
    }
    //无实质作用
    impl->addStrongRef(id);
    ...
    if (curCount == INITIAL_STRONG_VALUE) {
        impl->mStrong.fetch_sub(INITIAL_STRONG_VALUE,
                std::memory_order_relaxed);
    }

    return true;
}
```

```c++
bool RefBase::onIncStrongAttempted(uint32_t flags, const void* /*id*/)
{
    return (flags&FIRST_INC_STRONG) ? true : false;
}
```

# 5. sp 强指针

强指针的实现与弱指针机制相似，在创建时调用到RefBase的incStrong

```c++
//system/core/libutils/include/utils/StrongPointer.h
template<typename T>
sp<T>::sp(T* other)
        : m_ptr(other) {
    if (other)
        other->incStrong(this);
}
```

```c++
void RefBase::incStrong(const void* id) const
{
    weakref_impl* const refs = mRefs;
    //增加强引用计数时，首先要增加弱引用计数。
    refs->incWeak(id);
        
    refs->addStrongRef(id);
    //增加强引用计数
    const int32_t c = refs->mStrong.fetch_add(1, std::memory_order_relaxed);
    //成功时返回
    if (c != INITIAL_STRONG_VALUE)  {
        return;
    }
    //失败时回滚
    int32_t old __unused = refs->mStrong.fetch_sub(INITIAL_STRONG_VALUE, std::memory_order_relaxed);
    //调用RefBase的onFirstRef方法，子类可实现该方法完成初始化工作
    refs->mBase->onFirstRef();
}
```

现在再来对比下强弱指针的销毁时会如何处理:

```c++
template<typename T>
sp<T>::~sp() {
    if (m_ptr)
        m_ptr->decStrong(this);
}
```


```c++
void RefBase::decStrong(const void* id) const
{
    weakref_impl* const refs = mRefs;
    refs->removeStrongRef(id);
    //强引用计数自减
    const int32_t c = refs->mStrong.fetch_sub(1, std::memory_order_release);
    //此时只有一个强引用计数 
    if (c == 1) {
        //所有线程都能够在这个fence阶段看到mStrong被更新
        std::atomic_thread_fence(std::memory_order_acquire);
        refs->mBase->onLastStrongRef(id);
        int32_t flags = refs->mFlags.load(std::memory_order_relaxed);
        //如果当前对象由强引用计数控制，删除对象
        if ((flags&OBJECT_LIFETIME_MASK) == OBJECT_LIFETIME_STRONG) {
            delete this;
        }
    }
    //处理弱引用计数的自减
    refs->decWeak(id);
```

decStrong后，假如当前强引用计数不为0，则只是自减强引用计数，然后给到decWeak去处理弱引用计数。但假如强引用计数为0了，那么需要删除指向的对象，即delete this。


反观弱引用计数的自减:

```c++
template<typename T>
wp<T>::~wp()
{
    if (m_ptr) m_refs->decWeak(this);
}
```

```c++
void RefBase::weakref_type::decWeak(const void* id)
{
    weakref_impl* const impl = static_cast<weakref_impl*>(this);
    impl->removeWeakRef(id);
    //弱引用计数自减
    const int32_t c = impl->mWeak.fetch_sub(1, std::memory_order_release);
    //假如自减前的弱引用计数不为1，则返回 
    if (c != 1) return;
    //自减前的弱引用计数为1,更新原子状态
    atomic_thread_fence(std::memory_order_acquire);

    int32_t flags = impl->mFlags.load(std::memory_order_relaxed);
    if ((flags&OBJECT_LIFETIME_MASK) == OBJECT_LIFETIME_STRONG) {
        if (impl->mStrong.load(std::memory_order_relaxed)
                == INITIAL_STRONG_VALUE) {
            //当该应用对象未曾被强指针引用时，不做任何操作。不会去删除weakref_impl对象。 
        } else {
            //当该对象生命周期为强指针，即该对象是有强指针引用过的，
            //此时对象已经在强引用decStrong时被删除了,到这一步只需要删除与弱指针相关的weakref_impl对象即可
            delete impl;
        }
    } else {
        //此时该对象生命周期为OBJECT_LIFETIME_WEAK,即已经没有强指针引用该对象了，
        //此时可以大胆的删除对象
        impl->mBase->onLastWeakRef(id);
        delete impl->mBase;
    }
}
```

最后看下RefBase的析构函数:


```c++
RefBase::~RefBase()
{
    int32_t flags = mRefs->mFlags.load(std::memory_order_relaxed);
    //当生命周期被弱引用掌握时，且弱引用计数为0时，此处删除weakref_impl对象
	if ((flags & OBJECT_LIFETIME_MASK) == OBJECT_LIFETIME_WEAK) {
        if (mRefs->mWeak.load(std::memory_order_relaxed) == 0) {
            delete mRefs;
        }
    } else if (mRefs->mStrong.load(std::memory_order_relaxed)
            == INITIAL_STRONG_VALUE) {
		//当生命周期被强引用掌握时，且没被强引用引用过，在析构时，也会删除weakref_impl对象
        delete mRefs;
    }
    const_cast<weakref_impl*&>(mRefs) = NULL;
}
```

结合强弱引用计数的操作，可以假设如下情景:

情景1:
1. 初始化使用强指针指向该对象,默认mFlag为`OBJECT_LIFETIME_STRONG`，此时弱指针计数为1，强指针计数为1。
2. 强指针销毁，强引用计数减1，delete目标对象，弱指针引用计数减1。删除`weakref_impl`对象。
3. 调用RefBase析构函数，mRefs指向NULL。

情景2:
1. 初始化使用强指针，指向该对象，紧接着使用弱指针指向，此时强指针计数为1，弱指针计数为2。
2. 此时强指针销毁，弱引用计数减1，强引用计数当前为1，因此只要mFlag为`OBJECT_LIFETIME_STRONG`，就会直接删除对象。但是由于还有弱引用计数指向，所以不会去删除`weakref_impl`对象。

情景3:
1. 初始化使用弱指针指向该对象，默认mFlag为`OBJECT_LIFETIME_STRONG`,此时弱指针计数为1。
2. 弱指针销毁，弱引用计数减1，此时该对象未由强指针指向，所以不会做其他删除对象操作,删除`weakref_impl`对象。此时不会调用RefBase析构。

情景4：
1. 当前有一个强指针和弱指针指向同一个对象，此时强指针计数为1，弱指针计数为2。
2. 此时调用extendObjectLifetime(`OBJECT_LIFETIME_WEAK`),即延长生命周期的意思，并将mFlag改为`OBJECT_LIFETIME_WEAK`。此时假如强指针销毁，强指针计数为0，弱指针计数为1，但是不会去delete目标对象。
3. 紧接着假如销毁弱指针，则弱引用计数减1，且除此之外没有任何指针指向该对象了，可以删除`weakref_impl`的mBase(指向目标对象)。
4. 调用RefBase析构函数，删除`weakref_impl`对象。


最后给出智能指针销毁时的逻辑图:

![](/img/bill/in-posts/2019-05-15/sp_and_wp.png)

