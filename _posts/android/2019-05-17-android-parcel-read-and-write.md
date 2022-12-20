---
layout:     post
title:      "Android Parcel读写流程简析"
summary:    '"Android Parcel"'
date:       2019-05-17 14:34:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-05-17.jpg"
catalog: true
tags:
    - android
    - parcel
---

<!-- vim-markdown-toc GFM -->

* [1. 背景](#1-背景)
* [2. Framework层的Parcel](#2-framework层的parcel)
	* [2.1 Parcel写操作流程](#21-parcel写操作流程)
	* [2.2 Parcel读操作流程](#22-parcel读操作流程)
* [3. Parcel小结](#3-parcel小结)

<!-- vim-markdown-toc -->

# 1. 背景

Parcel在Binder通信被应用广泛，不仅仅可以传输Primitives数据，也可以传输继承/实现Parcelable接口的对象。本文将以其写/读数据流程，分析Parcel在传输数据中的实现细节。分析的SDK版本为Android P。

# 2. Framework层的Parcel

## 2.1 Parcel写操作流程

以ServiceManagerNative中定义的addService作为例子, 当Native层服务需要注册Binder服务时，都需要调用addService将服务注册到SeviceManagerService中。从而当客户端需要使用服务时，就可以通过ServiceManagerService去获取服务的代理，进行通信。

```java
//framework/base/core/java/android/os/ServiceManagerNative.java
public void addService(String name, IBinder service, boolean allowIsolated, int dumpPriority)
        throws RemoteException {
    Parcel data = Parcel.obtain();
    Parcel reply = Parcel.obtain();
    data.writeInterfaceToken(IServiceManager.descriptor);
    data.writeString(name);
    data.writeStrongBinder(service);
    data.writeInt(allowIsolated ? 1 : 0);
    data.writeInt(dumpPriority);
    mRemote.transact(ADD_SERVICE_TRANSACTION, data, reply, 0);
    reply.recycle();
    data.recycle();
}
```


首先来看Parcel的获取，Parcel本身开辟了一个Parcel池，数量是6。当调用obtain时，为了防止竞争，需要先锁住Parcel池，并遍历。假如找到一个Parcel对象非空，说明该Parcel并没有被使用，那么就首先把该数组的里的Parcel先保存起来，再将数组里的引用置空，最后返回该引用到用户。如果下个用户再次遍历该数组，就可以发现该Parcel为空，说明已经被别人使用了，就可以去使用后续的Parcel。

```java
//frameworks/base/core/java/android/os/Parcel.java
private static final int POOL_SIZE = 6;
private static final Parcel[] sOwnedPool = new Parcel[POOL_SIZE];
...
public static Parcel obtain() {
     final Parcel[] pool = sOwnedPool;
     synchronized (pool) {
         Parcel p;
         for (int i=0; i<POOL_SIZE; i++) {
             p = pool[i];
             if (p != null) {//说明该Parcel可以使用。
                 pool[i] = null;//置空说明该Parcel被这个调用者使用了。
                 ... 
                 p.mReadWriteHelper = ReadWriteHelper.DEFAULT;
                 return p;
             }
         }
     }
     //当前所有Parcel都被使用后，就可以新建Parcel。
     return new Parcel(0);
}
```

自然将会有一个方法和obtain对应，即recycle,可以看到当Parcel使用完毕后，会调用recycle将资源返回给Parcel类:

```java
//frameworks/base/core/java/android/os/Parcel.java
public final void recycle() {
    ...
    freeBuffer();

    final Parcel[] pool;
    if (mOwnsNativeParcelObject) {
        pool = sOwnedPool;
    } else {
        mNativePtr = 0;
        pool = sHolderPool;
    }
    //将Parcel归还到Parcel池中。
    synchronized (pool) {
        for (int i=0; i<POOL_SIZE; i++) {
            if (pool[i] == null) {
                pool[i] = this;
                return;
            }
        }
    }
}
```

当获取了Parcel后，就可以将数据填充到Parcel中了。首先调用了writeInterfaceToken.其中mNativePtr是在java层的Parcel创建后，会创建Native层的Parcel，mNativePtr正是指向Native层的Parcel.

```java
//frameworks/base/core/java/android/os/Parcel.java
public final void writeInterfaceToken(String interfaceName) {
    nativeWriteInterfaceToken(mNativePtr, interfaceName);
}
```

```c++
//frameworks/base/core/jni/android_os_Parcel.cpp
static void android_os_Parcel_writeInterfaceToken(JNIEnv* env, jclass clazz, jlong nativePtr,
                                                  jstring name)
{
    //获取Native层的Parcel对象
    Parcel* parcel = reinterpret_cast<Parcel*>(nativePtr);
    if (parcel != NULL) {
        //将name从java层转化为native层的字符串
        const jchar* str = env->GetStringCritical(name, 0);
        if (str != NULL) {
            //调用Native层Parcel的writeInterfaceToken
            parcel->writeInterfaceToken(String16(
                  reinterpret_cast<const char16_t*>(str),
                  env->GetStringLength(name)));
            env->ReleaseStringCritical(name, str);
        }
    }
}
```

```c++
//frameworks/native/libs/binder/Parcel.cpp
status_t Parcel::writeInterfaceToken(const String16& interface)
{
    writeInt32(IPCThreadState::self()->getStrictModePolicy() |
               STRICT_MODE_PENALTY_GATHER);
    //interface其根本也是字符串，即将Binder的接口写入到Parcel中。
    return writeString16(interface);
}
```

writeString16首先会调用writeInt32将String的长度写入，并通过计算，调用writeInplace创建内存空间，最后通过memcpy拷贝数据到该空间中。
```c++
//frameworks/native/libs/binder/Parcel.cpp
status_t Parcel::writeString16(const String16& str)
{
    return writeString16(str.string(), str.size());
}

status_t Parcel::writeString16(const char16_t* str, size_t len)
{
    if (str == NULL) return writeInt32(-1);
    
    status_t err = writeInt32(len);
    if (err == NO_ERROR) {
        len *= sizeof(char16_t);
        uint8_t* data = (uint8_t*)writeInplace(len+sizeof(char16_t));
        if (data) {
            memcpy(data, str, len);
            *reinterpret_cast<char16_t*>(data+len) = 0;
            return NO_ERROR;
        }
        err = mError;
    }
    return err;
}
```


其中writeInt32最终会调用到泛型函数writeAligned(事实上写基础类型数据，除了String，最后都会调用writeAligned)

```c++
//frameworks/native/libs/binder/Parcel.cpp
template<class T>
status_t Parcel::writeAligned(T val) {
    //mDataPos为当前Parcel的读写位置，再加上新的数据，假如长度并没有超过mDataCapacity(Parcel的数据总容量)
    if ((mDataPos+sizeof(val)) <= mDataCapacity) {
restart_write:
        //在起始位置mData+偏移mDataPos位置上赋值为val
        *reinterpret_cast<T*>(mData+mDataPos) = val;
        //调用finishWrite更新参数如mDataPos,mDataSize(当前数据的大小)
        return finishWrite(sizeof(val));
    }
    //这个位置即超过了数据容量了，需要调用growData进行扩容
    status_t err = growData(sizeof(val));
    //进行扩容后，重新回到上面进行写数据
    if (err == NO_ERROR) goto restart_write;
    return err;
}
```

growData对数据进行扩容，但如果len比`INT32_MAX`大时，会直接返回`BAD_VALUE`。每次扩容的大小是当前数据大小+增加数据的大小合共的1.5倍。最后调用continueWrite完成操作。
```c++
//frameworks/native/libs/binder/Parcel.cpp
status_t Parcel::growData(size_t len)
{
    if (len > INT32_MAX) {
        return BAD_VALUE;
    }

    size_t newSize = ((mDataSize+len)*3)/2;
    return (newSize <= mDataSize)
            ? (status_t) NO_MEMORY
            : continueWrite(newSize);
}
```

continueWrite的流程较长，以下分步进行分析:

```c++
//frameworks/native/libs/binder/Parcel.cpp
status_t Parcel::continueWrite(size_t desired)
{
    if (desired > INT32_MAX) {
        return BAD_VALUE;
    }
    ...
}
```

1.假如是第一次写数据，mData为空:

```c++
//分配desired大小的空间
uint8_t* data = (uint8_t*)malloc(desired);
if (!data) {
    mError = NO_MEMORY;
    return NO_MEMORY;
}

if(!(mDataCapacity == 0 && mObjects == NULL
     && mObjectsCapacity == 0)) {
    ALOGE("continueWrite: %zu/%p/%zu/%zu", mDataCapacity, mObjects, mObjectsCapacity, desired);
}
//利用gParcelGlobalAllocSizeLock全局分配锁更新gParcelGlobalAllocSize, gParcelGlobalAllocCount
pthread_mutex_lock(&gParcelGlobalAllocSizeLock);
gParcelGlobalAllocSize += desired;
gParcelGlobalAllocCount++;
pthread_mutex_unlock(&gParcelGlobalAllocSizeLock);
//赋值分配的空间地址到mData基址地址上。
mData = data;
mDataSize = mDataPos = 0;
//Parcel容量大小设置为desired大小
mDataCapacity = desired;
```


2.假如不是第一次写数据，mData非空:

```c++
if (desired > mDataCapacity) {
    //通过realloc分配desired的内存，假如大小超过以前的，将会移到新的内存块上，返回新的基地址
    uint8_t* data = (uint8_t*)realloc(mData, desired);
    if (data) {
        //利用gParcelGlobalAllocSizeLock全局分配锁更新gParcelGlobalAllocSize, gParcelGlobalAllocCount
        pthread_mutex_lock(&gParcelGlobalAllocSizeLock);
        gParcelGlobalAllocSize += desired;
        gParcelGlobalAllocSize -= mDataCapacity;
        pthread_mutex_unlock(&gParcelGlobalAllocSizeLock);
        mData = data;
        mDataCapacity = desired;
    } else {
        mError = NO_MEMORY;
        return NO_MEMORY;
    }
} else {
    if (mDataSize > desired) {
        mDataSize = desired;
    }
    if (mDataPos > desired) {
        mDataPos = desired;
    }
}
```

上述continueWrite忽略了对传输Binder对象的处理，可以更直观的理解这个过程。至此只是完成了writeInt32的流程，回到writeString16中:

```c++
//frameworks/native/libs/binder/Parcel.cpp
status_t Parcel::writeString16(const char16_t* str, size_t len)
{
    if (str == NULL) return writeInt32(-1);
    //上述完成这个步骤分析    
    status_t err = writeInt32(len);
    if (err == NO_ERROR) {
        len *= sizeof(char16_t);
        uint8_t* data = (uint8_t*)writeInplace(len+sizeof(char16_t));
        if (data) {
            memcpy(data, str, len);
            *reinterpret_cast<char16_t*>(data+len) = 0;
            return NO_ERROR;
        }
        err = mError;
    }
    return err;
}
```

最终的目的是要将string内容写入，长度为len的String占用的大小是len * sizeof(char16_t),writeInplace的实现如下:

```c++
//frameworks/native/libs/binder/Parcel.cpp
void* Parcel::writeInplace(size_t len)
{
    if (len > INT32_MAX) {
        return NULL;
    }
    //计算以4字节对齐时，需要使用多少空间 PAD_SIZE_UNSAFE(s) (((s)+3)&~3)
    const size_t padded = pad_size(len);

    //检查整数是否溢出
    if (mDataPos+padded < mDataPos) {
        return NULL;
    }
    //是否在容量之内？
    if ((mDataPos+padded) <= mDataCapacity) {
restart_write:
        uint8_t* const data = mData+mDataPos;
        if (padded != len) {
//大端操作
#if BYTE_ORDER == BIG_ENDIAN
            static const uint32_t mask[4] = {
                0x00000000, 0xffffff00, 0xffff0000, 0xff000000
            };
#endif
//小端操作
#if BYTE_ORDER == LITTLE_ENDIAN
            static const uint32_t mask[4] = {
                0x00000000, 0x00ffffff, 0x0000ffff, 0x000000ff
            };
#endif
            //填充尾部数据
            *reinterpret_cast<uint32_t*>(data+padded-4) &= mask[padded-len];
        }
        //更新Parcel参数数据
        finishWrite(padded);
        return data;
    }
    //说明超过容量了，需要调用growData进行扩容
    status_t err = growData(padded);
    if (err == NO_ERROR) goto restart_write;
    return NULL;
}
```

最后通过memcpy拷贝数据，完成整个writeString16操作。

```c++
memcpy(data, str, len);
*reinterpret_cast<char16_t*>(data+len) = 0;
```


相比传输基础数据是传输内容，传输过程中其实并不是原来的那个对象。那么如果是传递Binder时就不太一样了。创建了Binder进行传输，可以获得其本身或者是转化为其代理端，从而使传输对端能够获取到服务。writeStrongBinder就是完成了这样的工作:

```java
//frameworks/base/core/java/android/os/Parcel.java
public final void writeStrongBinder(IBinder val) {
    nativeWriteStrongBinder(mNativePtr, val);
}
```

最终java层还是会需要Native层的writeStrongBinder实现。同时上层的java对象IBinder，会通过ibinderForJavaObject进行转换。转换为Native层的IBinder对象。
```c++
//frameworks/base/core/jni/android_os_Parcel.cpp
static void android_os_Parcel_writeStrongBinder(JNIEnv* env, jclass clazz, jlong nativePtr, jobject object)
{
    Parcel* parcel = reinterpret_cast<Parcel*>(nativePtr);
    if (parcel != NULL) {
        const status_t err = parcel->writeStrongBinder(ibinderForJavaObject(env, object));
        if (err != NO_ERROR) {
            signalExceptionForError(env, clazz, err);
        }
    }
}
```

首先来看下ibinderForJavaObject方法，Java的Binder对象分为两类，一类是Binder服务类，另一类是Binder代理类。该方法实际上就是从Java层获取到Native层与之对应的对象。

```c++
//frameworks/base/core/jni/android_util_Binder.cpp
sp<IBinder> ibinderForJavaObject(JNIEnv* env, jobject obj)
{
    if (obj == NULL) return NULL;

    //检查是否为Binder服务端,获取IBinder的属性取得一个JavaBBinderHolder对象，
    //并从中获取Native层的Binder对象
    //(Binder在Java层初始化时，会创建一个Native层的JavaBBinderHolder对象保存在Java层的mObject属性中)
    if (env->IsInstanceOf(obj, gBinderOffsets.mClass)) {
        JavaBBinderHolder* jbh = (JavaBBinderHolder*)
            env->GetLongField(obj, gBinderOffsets.mObject);
        return jbh->get(env, obj);
    }
    //检查是否为Binder的代理端，调用getBpNativeData获取代理对象。
    //(BinderProxy与Binder类似，在Java层初始化时，会将C++的BinderProxy地址保存到mNativeData中，getBPNativeData就是返回这个地址，即BinderProxy对应的Native对象)
    if (env->IsInstanceOf(obj, gBinderProxyOffsets.mClass)) {
        return getBPNativeData(env, obj)->mObject;
    }

    return NULL;
}
```

至此可以知道writeStrongBidner传输的都是Native层的Binder对象。接着关注writeStrongBinder的实现细节。flattern意味要将binder对象扁平化的意思。
```c++
//frameworks/native/libs/binder/Parcel.cpp
status_t Parcel::writeStrongBinder(const sp<IBinder>& val)
{
    return flatten_binder(ProcessState::self(), val, this);
}
```


```c++
//frameworks/native/libs/binder/Parcel.cpp
status_t flatten_binder(const sp<ProcessState>& /*proc*/,
    const sp<IBinder>& binder, Parcel* out)
{
    flat_binder_object obj;

    if (IPCThreadState::self()->backgroundSchedulingDisabled()) {
        obj.flags = FLAT_BINDER_FLAG_ACCEPTS_FDS;
    } else {
        obj.flags = 0x13 | FLAT_BINDER_FLAG_ACCEPTS_FDS;
    }

    if (binder != NULL) {
        //local不为空时，传递的为Binder服务，为空时，传递的是Binder的代理
        //BBinder的localBinder返回本身，而BpBinder并没有实现该方法，使用基类方法将返回NULL
		IBinder *local = binder->localBinder();
        if (!local) {//传递Binder proxy
            BpBinder *proxy = binder->remoteBinder();
            if (proxy == NULL) {
                ALOGE("null proxy");
            }
            const int32_t handle = proxy ? proxy->handle() : 0;
            obj.hdr.type = BINDER_TYPE_HANDLE;
            obj.binder = 0; /* Don't pass uninitialized stack data to a remote process */
            obj.handle = handle;//handle保存的是handle值
            obj.cookie = 0;
        } else {//传递Binder服务,Binder注册服务时，常走这一段逻辑
            obj.hdr.type = BINDER_TYPE_BINDER;
            obj.binder = reinterpret_cast<uintptr_t>(local->getWeakRefs());//binder保存的是weakref_impl的地址
            obj.cookie = reinterpret_cast<uintptr_t>(local);//cookie保存的即IBinder对象
        }
    } else {
        obj.hdr.type = BINDER_TYPE_BINDER;
        obj.binder = 0;
        obj.cookie = 0;
    }

    return finish_flatten_binder(binder, obj, out);
}
```

2019/05/23更新:阅读了Binder的驱动可得知，`flat_binder_object`是底层驱动的数据结构，当传输数据包括Binder对象时，将会以`flat_binder_object`结构进行传输。其中传输的类型分为:

```c
	BINDER_TYPE_BINDER	= B_PACK_CHARS('s', 'b', '*', B_TYPE_LARGE),//强Binder实体(服务)
	BINDER_TYPE_WEAK_BINDER	= B_PACK_CHARS('w', 'b', '*', B_TYPE_LARGE),//弱Binder实体(服务)
	BINDER_TYPE_HANDLE	= B_PACK_CHARS('s', 'h', '*', B_TYPE_LARGE),//强Binder引用对象(代理)
	BINDER_TYPE_WEAK_HANDLE	= B_PACK_CHARS('w', 'h', '*', B_TYPE_LARGE),//弱Binder引用对象(代理)
	BINDER_TYPE_FD		= B_PACK_CHARS('f', 'd', '*', B_TYPE_LARGE),//文件描述符
	BINDER_TYPE_FDA		= B_PACK_CHARS('f', 'd', 'a', B_TYPE_LARGE),//文件描述符
	BINDER_TYPE_PTR		= B_PACK_CHARS('p', 't', '*', B_TYPE_LARGE),
```

再来看下`flat_binder_object`的定义:

```c
struct flat_binder_object {
	struct binder_object_header	hdr;
	__u32				flags;

	/* 8 bytes of data. */
	union {
		binder_uintptr_t	binder;	/* local object */
		__u32			handle;	/* remote object */
	};

	/* extra data associated with local object */
	binder_uintptr_t	cookie;
};

```

hdr进行传输类型的区分，即上述说的服务还是代理。当为服务时，binder会保存Service的`weakref_impl`地址，cookie保存IBinder地址。为代理时，则handle保存的是底层的Binder引用对象(binder_ref)的句柄值(desc)。


调用writeObject将`flat_binder_object`写入out中。

```c++
//frameworks/native/libs/binder/Parcel.cpp
inline static status_t finish_flatten_binder(
    const sp<IBinder>& /*binder*/, const flat_binder_object& flat, Parcel* out)
{
    return out->writeObject(flat, false);
}
```

最后看下writeObject的实现:


```c++
//frameworks/native/libs/binder/Parcel.cpp
status_t Parcel::writeObject(const flat_binder_object& val, bool nullMetaData)
{
    //假如是传递对象，Parcel中会维护对象的大小mObjectsSize以及容量mObjectsCapacity
    //保证当前容量足够
    const bool enoughData = (mDataPos+sizeof(val)) <= mDataCapacity;
    //保证当前对象容量也足够
    const bool enoughObjects = mObjectsSize < mObjectsCapacity;
    if (enoughData && enoughObjects) {
restart_write:
        //写数据
        *reinterpret_cast<flat_binder_object*>(mData+mDataPos) = val;

        if (val.hdr.type == BINDER_TYPE_FD) {
            if (!mAllowFds) {
                return FDS_NOT_ALLOWED;
            }
            mHasFds = mFdsKnown = true;
        }
        //更新Parcel维护的对象信息
        if (nullMetaData || val.binder != 0) {
            mObjects[mObjectsSize] = mDataPos;
            acquire_object(ProcessState::self(), val, this, &mOpenAshmemSize);
            mObjectsSize++;
        }

        return finishWrite(sizeof(flat_binder_object));
    }
    //容量不足时扩容
    if (!enoughData) {
        const status_t err = growData(sizeof(val));
        if (err != NO_ERROR) return err;
    }
    //对象容量不足时，也需要重新申请内存
    if (!enoughObjects) {
        size_t newSize = ((mObjectsSize+2)*3)/2;
        if (newSize*sizeof(binder_size_t) < mObjectsSize) return NO_MEMORY;   // overflow
        binder_size_t* objects = (binder_size_t*)realloc(mObjects, newSize*sizeof(binder_size_t));
        if (objects == NULL) return NO_MEMORY;
        mObjects = objects;
        mObjectsCapacity = newSize;
    }

    goto restart_write;
}
```

## 2.2 Parcel读操作流程

与上述逆过程时，在Native层会有一个`unflatten_binder`,与之前的`flatten_binder`对应:

```c++
//frameworks/native/libs/binder/Parcel.cpp
status_t unflatten_binder(const sp<ProcessState>& proc,
    const Parcel& in, sp<IBinder>* out)
{
    //反序列化
    const flat_binder_object* flat = in.readObject(false);

    if (flat) {
        switch (flat->hdr.type) {
            case BINDER_TYPE_BINDER://Binder服务
                *out = reinterpret_cast<IBinder*>(flat->cookie);
                return finish_unflatten_binder(NULL, *flat, in);
            case BINDER_TYPE_HANDLE://Binder代理
                *out = proc->getStrongProxyForHandle(flat->handle);
                return finish_unflatten_binder(
                    static_cast<BpBinder*>(out->get()), *flat, in);
        }
    }
    return BAD_TYPE;
}
```


至于readObject流程如下,返回的是一个`flat_binder_object`

```c++
//frameworks/native/libs/binder/Parcel.cpp
const flat_binder_object* Parcel::readObject(bool nullMetaData) const
{
    const size_t DPOS = mDataPos;
    if ((DPOS+sizeof(flat_binder_object)) <= mDataSize) {
        //从基地址mData加偏移mDataPos的位置中读取数据,强制转换为flat_bidner_object
        const flat_binder_object* obj
                = reinterpret_cast<const flat_binder_object*>(mData+DPOS);
        mDataPos = DPOS + sizeof(flat_binder_object);
        //当读取的对象中为空时，不会去进行进一步检查，也不会更新到objects相关的信息中。只是返回。
        if (!nullMetaData && (obj->cookie == 0 && obj->binder == 0)) {
            return obj;
        }
        //后续的操作是确保这个object对象是有效的。 
        binder_size_t* const OBJS = mObjects;
        const size_t N = mObjectsSize;
        size_t opos = mNextObjectHint;

        if (N > 0) {
            if (opos < N) {
                //从前往后找
                while (opos < (N-1) && OBJS[opos] < DPOS) {
                    opos++;
                }
            } else {
                opos = N-1;
            }
            if (OBJS[opos] == DPOS) {
                //找到目标
                mNextObjectHint = opos+1;
                return obj;
            }

            //从后往前找 
            while (opos > 0 && OBJS[opos] > DPOS) {
                opos--;
            }
            if (OBJS[opos] == DPOS) {
                //找到目标
                mNextObjectHint = opos+1;
                return obj;
            }
        }
    }
    return NULL;
}
```

# 3. Parcel小结
从读写操作看，Parcel中实际进行读写的是在Native层实现，且写操作时，会根据数据的容量去动态扩容。在读写看，Parcel在跨进程操作时，都是读取基地址和偏移量的值的内容。从Binder的底层实现是内存映射的模型，Parcel看起来也是在这一块内存映射中进行读写，实现跨进程的内容的传输的。

