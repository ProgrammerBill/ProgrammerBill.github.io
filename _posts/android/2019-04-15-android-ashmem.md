---
layout:     post
title:      "Android 匿名内存分析"
summary:    '"anoymous shared memory"'
date:       2019-04-15 17:30:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-04-15.jpg"
catalog: true
tags:
    - android
    - memory
---


<!-- vim-markdown-toc GFM -->

* [1. 概述](#1-概述)
* [2. AShmem驱动](#2-ashmem驱动)
	* [2.1 `ashmem_init`](#21-ashmem_init)
	* [2.2 `ashmem_open`](#22-ashmem_open)
	* [2.3 `ashmem_mmap`](#23-ashmem_mmap)
* [3. AShmem Android实例](#3-ashmem-android实例)
	* [3.1 AudioFlinger知识准备](#31-audioflinger知识准备)
	* [3.2 AudioTrack知识准备](#32-audiotrack知识准备)
	* [3.3 AudioTrack的初始化](#33-audiotrack的初始化)
	* [3.4 AudioFlinger创建AShemem](#34-audioflinger创建ashemem)
	* [3.5 AudioTrack映射Ashemem](#35-audiotrack映射ashemem)

<!-- vim-markdown-toc -->

# 1. 概述

AShmem即Anoymous Shared Memory，即匿名共享内存,属于Android特有的内存共享机制，利用AShmem可以将指定的物理内存映射到各个进程的虚拟空间中，实现内存共享.

学习的总体框架如下:


![](/img/bill/in-posts/2019-04-15/AShmemFramework.png)

[大图链接](http://www.cjcbill.com/img/bill/in-posts/2019-04-15/AShmemFramework.png) 

# 2. AShmem驱动

为了更好的理解AShmem的工作原理，先从驱动的实现开始分析:

## 2.1 `ashmem_init`

```c
static int __init ashmem_init(void)
{
	int ret = -ENOMEM;
	//创建一块名为"ashmem_area_cache"的cache内存
	ashmem_area_cachep = kmem_cache_create("ashmem_area_cache",
			sizeof(struct ashmem_area),
			0, 0, NULL);
	if (unlikely(!ashmem_area_cachep)) {
		pr_err("failed to create slab cache\n");
		goto out;
	}

	//创建一块名为"ashmem_range_cache"的cache内存
	ashmem_range_cachep = kmem_cache_create("ashmem_range_cache",
			sizeof(struct ashmem_range),
			0, 0, NULL);
	if (unlikely(!ashmem_range_cachep)) {
		pr_err("failed to create slab cache\n");
		goto out_free1;
	}
	//注册misc设备
	ret = misc_register(&ashmem_misc);
	if (unlikely(ret)) {
		pr_err("failed to register misc device!\n");
		goto out_free2;
	}

	register_shrinker(&ashmem_shrinker);

	pr_info("initialized\n");

	return 0;

out_free2:
	kmem_cache_destroy(ashmem_range_cachep);
out_free1:
	kmem_cache_destroy(ashmem_area_cachep);
out:
	return ret;
}
device_initcall(ashmem_init);
```

从AShmem的注册方式，可以看出其常用的方法包括`ashmem_open`,`ashemem_release`,`ashmem_mmap`等．
```c
static const struct file_operations ashmem_fops = {
	.owner = THIS_MODULE,
	.open = ashmem_open,
	.release = ashmem_release,
	.read = ashmem_read,
	.llseek = ashmem_llseek,
	.mmap = ashmem_mmap,
	.unlocked_ioctl = ashmem_ioctl,
#ifdef CONFIG_COMPAT
	.compat_ioctl = compat_ashmem_ioctl,
#endif
};

static struct miscdevice ashmem_misc = {
	.minor = MISC_DYNAMIC_MINOR,
	.name = "ashmem",
	.fops = &ashmem_fops,
};
```

## 2.2 `ashmem_open`

```c
static int ashmem_open(struct inode *inode, struct file *file)
{
	struct ashmem_area *asma;
	int ret;

	ret = generic_file_open(inode, file);
	if (unlikely(ret))
		return ret;
	//为ashmem_area_cachep分配内存
	asma = kmem_cache_zalloc(ashmem_area_cachep, GFP_KERNEL);
	if (unlikely(!asma))
		return -ENOMEM;
	//初始化链表
	INIT_LIST_HEAD(&asma->unpinned_list);
	memcpy(asma->name, ASHMEM_NAME_PREFIX, ASHMEM_NAME_PREFIX_LEN);
	asma->prot_mask = PROT_MASK;
	//将内存保存在private_data中
	file->private_data = asma;

	return 0;
}
```

## 2.3 `ashmem_mmap`

```c
static int ashmem_mmap(struct file *file, struct vm_area_struct *vma)
{
	//获取创建的内存
	struct ashmem_area *asma = file->private_data;
	int ret = 0;

	mutex_lock(&ashmem_mutex);

	/* user needs to SET_SIZE before mapping */
	if (unlikely(!asma->size)) {
		ret = -EINVAL;
		goto out;
	}

	/* requested protection bits must match our allowed protection mask */
	if (unlikely((vma->vm_flags & ~calc_vm_prot_bits(asma->prot_mask, 0)) &
				calc_vm_prot_bits(PROT_MASK, 0))) {
		ret = -EPERM;
		goto out;
	}
	vma->vm_flags &= ~calc_vm_may_flags(~asma->prot_mask);

	if (!asma->file) {
		//ASHMEM_NAME_DEF定义为"dev/ashmem"
		char *name = ASHMEM_NAME_DEF;
		struct file *vmfile;

		if (asma->name[ASHMEM_NAME_PREFIX_LEN] != '\0')
			name = asma->name;

		/* ... and allocate the backing shmem file */
		//创建临时文件vmfile，用于内存映射
		vmfile = shmem_file_setup(name, asma->size, vma->vm_flags);
		if (IS_ERR(vmfile)) {
			ret = PTR_ERR(vmfile);
			goto out;
		}
		vmfile->f_mode |= FMODE_LSEEK;
		asma->file = vmfile;
	}
	get_file(asma->file);
	//内存映射
	if (vma->vm_flags & VM_SHARED)
		shmem_set_file(vma, asma->file);
	else {
		if (vma->vm_file)
			fput(vma->vm_file);
		vma->vm_file = asma->file;
	}

out:
	mutex_unlock(&ashmem_mutex);
	return ret;
}
```

小结:

从驱动层面来看,AShmem创建了一个临时文件，/dev/ashmem的内存空间就是创建该临时文件中获取的，创建完成后，调用`shemem_set_file`完成内存映射．那么进程操作/dev/ashmem节点，就相当于直接对该临时文件进行操作．假如有多个进程，只要能够获取相同的的fd(打开/dev/ashmem)，那么就可以实现匿名共享内存的进程间通信了．那么在fd的获取时，Android在跨进程中就可以通过Binder来获取同一个fd实现．

# 3. AShmem Android实例

## 3.1 AudioFlinger知识准备

匿名共享内存有一个经典的应用案例是AudioFlinger以及AudioTrack．其中AudioFlinger常驻在audioserver进程当中，其启动rc文件如下:

```
#frameworks/av/media/audioserver/audioserver.rc
service audioserver /system/bin/audioserver
    class core
    user audioserver
    # media gid needed for /dev/fm (radio) and for /data/misc/media (tee)
    group audio camera drmrpc inet media mediadrm net_bt net_bt_admin net_bw_acct
    ioprio rt 4
    writepid /dev/cpuset/foreground/tasks /dev/stune/foreground/tasks
    onrestart restart vendor.audio-hal-2-0
    # Keep the original service name for backward compatibility when upgrading
    # O-MR1 devices with framework-only.
    onrestart restart audio-hal-2-0
```

audioserver启动时，调用AudioFlinger::instantiate()启动了AudioFlinger:

```c++
//frameworks/av/media/audioserver/main_audioserver.cpp
   int main(int argc __unused, char **argv)
   {
    ...
    sp<ProcessState> proc(ProcessState::self());
    sp<IServiceManager> sm = defaultServiceManager();
    ALOGI("ServiceManager: %p", sm.get());
    //AudioFlinger初始化，主要将该服务加入ServiceManagerService中
    AudioFlinger::instantiate();
    AudioPolicyService::instantiate();
    ...
    aaudio_policy_t mmapPolicy = property_get_int32(AAUDIO_PROP_MMAP_POLICY,
                                                    AAUDIO_POLICY_NEVER);
    if (mmapPolicy == AAUDIO_POLICY_AUTO || mmapPolicy == AAUDIO_POLICY_ALWAYS) {
        AAudioService::instantiate();
    }

    SoundTriggerHwService::instantiate();
    //新建一个新线程用于监听binder驱动进行通信．
    ProcessState::self()->startThreadPool();
    //为了不让该进程退出，调用joinThreadPool阻塞主线程．等待binder线程完成工作后退出．
    IPCThreadState::self()->joinThreadPool();
```

AudioFlinger之所以可以用instantiate方法进行初始化，是因为其继承了BinderService，初始化的细节都在父类中实现了．首先获取ServiceManger，并自身注册到ServcieManger中．

```c++
//frameworks/av/services/audioflinger/AudioFlinger.h
class AudioFlinger :
    public BinderService<AudioFlinger>,
    public BnAudioFlinger
    ...
```

```c++
//frameworks/native/libs/binder/include/binder/BinderService.h
template<typename SERVICE>
class BinderService
{
public:
    static status_t publish(bool allowIsolated = false,
    int dumpFlags = IServiceManager::DUMP_FLAG_PRIORITY_DEFAULT) {
    sp<IServiceManager> sm(defaultServiceManager());
    return sm->addService(String16(SERVICE::getServiceName()), new SERVICE(), allowIsolated,
        dumpFlags);
    }
static void instantiate() { publish(); }
...
}
```

## 3.2 AudioTrack知识准备

AudioTrack可用于播放音频文件，一个典型的例子如下:

```c++
@LargeTest
    public void testPlaybackHeadPositionAfterFlush() throws Exception {
        // constants for test
        final String TEST_NAME = "testPlaybackHeadPositionAfterFlush";
        final int TEST_SR = 22050;//采样率
        final int TEST_CONF = AudioFormat.CHANNEL_OUT_STEREO;//声道数
        final int TEST_FORMAT = AudioFormat.ENCODING_PCM_16BIT;//采样精度
        final int TEST_MODE = AudioTrack.MODE_STREAM;//数据加载类型,STREAM或者STATIC
        final int TEST_STREAM_TYPE = AudioManager.STREAM_MUSIC;//音频流类型

        //-------- initialization --------------
        int minBuffSize = AudioTrack.getMinBufferSize(TEST_SR, TEST_CONF, TEST_FORMAT);
        //创建AudioTrack
        AudioTrack track = new AudioTrack(TEST_STREAM_TYPE, TEST_SR, TEST_CONF, TEST_FORMAT, minBuffSize, TEST_MODE);
        byte data[] = new byte[minBuffSize/2];
        //--------    test        --------------
        assumeTrue(TEST_NAME, track.getState() == AudioTrack.STATE_INITIALIZED);
        track.write(data, 0, data.length);
        //播放音频
        track.play();
        Thread.sleep(100);
        track.stop();
        track.flush();
        log(TEST_NAME, "position ="+ track.getPlaybackHeadPosition());
        assertTrue(TEST_NAME, track.getPlaybackHeadPosition() == 0);
        //-------- tear down      --------------
        track.release();
    }
```

由此可见，AudioFlinger在Android P中工作在audioserver进程，AudioTrack工作在另一个进程，但二者使用了匿名共享内存实现了通信．

Android P关于这两者的匿名内存还实现了一个测试用例,返回0时通过测试，后续分析完，将针对该例子进行分析．

```c++
#define BUF_SZ 44100
int AudioTrackTest::Test01() {
    sp<MemoryDealer> heap;
    sp<IMemory> iMem;
    uint8_t* p;
    short smpBuf[BUF_SZ];
    long rate = 44100;
    unsigned long phi;
    unsigned long dPhi;
    long amplitude;
    long freq = 1237;
    float f0;
    f0 = pow(2., 32.) * freq / (float)rate;
    dPhi = (unsigned long)f0;
    amplitude = 1000;
    phi = 0;
    Generate(smpBuf, BUF_SZ, amplitude, phi, dPhi);  // fill buffer

    for (int i = 0; i < 1024; i++) {
        heap = new MemoryDealer(1024*1024, "AudioTrack Heap Base");

        iMem = heap->allocate(BUF_SZ*sizeof(short));

        p = static_cast<uint8_t*>(iMem->pointer());
        memcpy(p, smpBuf, BUF_SZ*sizeof(short));
        //Audiotrack可以指定共享内存参数并传入
        sp<AudioTrack> track = new AudioTrack(AUDIO_STREAM_MUSIC,// stream type
               rate,
               AUDIO_FORMAT_PCM_16_BIT,// word length, PCM
               AUDIO_CHANNEL_OUT_MONO,
               iMem);

        status_t status = track->initCheck();
        if(status != NO_ERROR) {
            track.clear();
            ALOGD("Failed for initCheck()");
            return -1;
        }

        // start play
        ALOGD("start");
        track->start();

        usleep(20000);
        ALOGD("stop");
        track->stop();
        iMem.clear();
        heap.clear();
        usleep(20000);
    }
    return 0;
}
```

## 3.3 AudioTrack的初始化

当客户端新建一个AudioTrack时，会经过new AudioTrack()调用到set(),再到`createTrack_l()`,部分关键代码如下:

```c++
//frameworks/av/media/libaudioclient/AudioTrack.cpp
AudioTrack::AudioTrack(
        audio_stream_type_t streamType,
        uint32_t sampleRate,
        audio_format_t format,
        audio_channel_mask_t channelMask,
        size_t frameCount,
        audio_output_flags_t flags,
        callback_t cbf,
        void* user,
        int32_t notificationFrames,
        audio_session_t sessionId,
        transfer_type transferType,
        const audio_offload_info_t *offloadInfo,
        uid_t uid,
        pid_t pid,
        const audio_attributes_t* pAttributes,
        bool doNotReconnect,
        float maxRequiredSpeed,
        audio_port_handle_t selectedDeviceId)
    : mStatus(NO_INIT),
      mState(STATE_STOPPED),
      mPreviousPriority(ANDROID_PRIORITY_NORMAL),
      mPreviousSchedulingGroup(SP_DEFAULT),
      mPausedPosition(0)
{
    (void)set(streamType, sampleRate, format, channelMask,
            frameCount, flags, cbf, user, notificationFrames,
            0 /*sharedBuffer*/, false /*threadCanCallJava*/, sessionId, transferType,
            offloadInfo, uid, pid, pAttributes, doNotReconnect, maxRequiredSpeed, selectedDeviceId);
}
```

```c++
//frameworks/av/media/libaudioclient/AudioTrack.cpp
status_t AudioTrack::set(
        audio_stream_type_t streamType,
        uint32_t sampleRate,
        audio_format_t format,
        audio_channel_mask_t channelMask,
        size_t frameCount,
        audio_output_flags_t flags,
        callback_t cbf,
        void* user,
        int32_t notificationFrames,
        const sp<IMemory>& sharedBuffer,
        bool threadCanCallJava,
        audio_session_t sessionId,
        transfer_type transferType,
        const audio_offload_info_t *offloadInfo,
        uid_t uid,
        pid_t pid,
        const audio_attributes_t* pAttributes,
        bool doNotReconnect,
        float maxRequiredSpeed,
        audio_port_handle_t selectedDeviceId)
{
...
// create the IAudioTrack
status = createTrack_l();
...
}
```

`createTrack_l`涉及的内容较多，其中通过Binder通信BpAudioFlinger向BnAudioFlinger，即AudioFlinger请求调用createTrack.这里面会创建匿名共享内存．待服务端AudioFlinger创建完毕后，通过一系列动作`track->getCblk()`，`iMem->pointer()`等将AudioFlinger创建的内存映射到AudioTrack进程中．后续将逐点深入分析.

```c++
//frameworks/av/media/libaudioclient/AudioTrack.cpp
status_t AudioTrack::createTrack_l()
{
...
    const sp<IAudioFlinger>& audioFlinger = AudioSystem::get_audio_flinger();
    //借助audioFlinger创建TrackHandle类型的对象，其有一个PlaybackThread的对象
    sp<IAudioTrack> track = audioFlinger->createTrack(input,
                                                  output,
                                                  &status);
    ...
    //通过Binder通信获取AudioFlinger中的内存映射信息,并映射到本进程
    sp<IMemory> iMem = track->getCblk();
    void *iMemPointer = iMem->pointer();
    ...
    mAudioTrack = track;
    mCblkMemory = iMem;
    ....
    audio_track_cblk_t* cblk = static_cast<audio_track_cblk_t*>(iMemPointer);
    mCblk = cblk;
    ...
}
```

## 3.4 AudioFlinger创建AShemem

当AudioTrack调用到AudioFlinger的createTrack方法时，会调用到:

```c++
//frameworks/av/services/audioflinger/AudioFlinger.cpp
sp<IAudioTrack> AudioFlinger::createTrack(const CreateTrackInput& input,
                                          CreateTrackOutput& output,
                                          status_t *status)
{
...
    client = registerPid(clientPid);
...
}
```

该方法会创建一个Client对象,并将其加入到mClients中进行维护．可以看出，每当有新AudioTrack，在AudioFlinger这端都会有一个Client与之对应，AudioFlinger就可以根据Client获取到客户端的pid等信息．

```c++
//frameworks/av/services/audioflinger/AudioFlinger.cpp
sp<AudioFlinger::Client> AudioFlinger::registerPid(pid_t pid)
{
    Mutex::Autolock _cl(mClientLock);
    // If pid is already in the mClients wp<> map, then use that entry
    // (for which promote() is always != 0), otherwise create a new entry and Client.
    sp<Client> client = mClients.valueFor(pid).promote();
    if (client == 0) {
        client = new Client(this, pid);
        mClients.add(pid, client);
    }
    return client;
}
```

当Client新建后，会新建MemoryDealer对象，并赋值到mMemoryDealer中，这个就是与AShmem相关的部分．

```c++
//frameworks/av/services/audioflinger/AudioFlinger.cpp
AudioFlinger::Client::Client(const sp<AudioFlinger>& audioFlinger, pid_t pid)
    :   RefBase(),
        mAudioFlinger(audioFlinger),
        mPid(pid)
{
    mMemoryDealer = new MemoryDealer(
            audioFlinger->getClientSharedHeapSize(),
            (std::string("AudioFlinger::Client(") + std::to_string(pid) + ")").c_str());
}
```

MemoryDealer在初始化时，会new一个MemoryHeapBase对象

```c++
//framework/native/libs/binder/MemoryDealer.cpp
MemoryDealer::MemoryDealer(size_t size, const char* name, uint32_t flags)
    : mHeap(new MemoryHeapBase(size, flags, name)),
    mAllocator(new SimpleBestFitAllocator(size))
{
}
```

`ashmem_create_region`会打开/dev/ashmem节点，并在打开正常时，使用mapfd将设备空间映射到进程中.

```c++
//frameworks/native/libs/binder/MemoryHeapBase.cpp
MemoryHeapBase::MemoryHeapBase(size_t size, uint32_t flags, char const * name)
    : mFD(-1), mSize(0), mBase(MAP_FAILED), mFlags(flags),
      mDevice(0), mNeedUnmap(false), mOffset(0)
{
    const size_t pagesize = getpagesize();
    size = ((size + pagesize-1) & ~(pagesize-1));
    int fd = ashmem_create_region(name == NULL ? "MemoryHeapBase" : name, size);
    ALOGE_IF(fd<0, "error creating ashmem region: %s", strerror(errno));
    if (fd >= 0) {
        if (mapfd(fd, size) == NO_ERROR) {
            if (flags & READ_ONLY) {
                ashmem_set_prot_region(fd, PROT_READ);
            }
        }
    }
}
```

`ashmem_create_region`打开/dev/ashmem节点，并通过连续两次ioctl操作分别设置名字(`ASHMEM_SET_NAME`)与大小(`ASHMEM_SET_SIZE`)，默认名为"MemoryHeapBase",具体实现可参考第一小节内容．

```c++
//system/core/libcutils/ashmem-dev.cpp
int ashmem_create_region(const char *name, size_t size)
{
    int ret, save_errno;
    //打开"/dev/ashmem"设备节点
    int fd = __ashmem_open();
    if (fd < 0) {
        return fd;
    }

    if (name) {
        char buf[ASHMEM_NAME_LEN] = {0};

        strlcpy(buf, name, sizeof(buf));
        //通过ioctl设置Ashmem名
        ret = TEMP_FAILURE_RETRY(ioctl(fd, ASHMEM_SET_NAME, buf));
        if (ret < 0) {
            goto error;
        }
    }
    //通过ioctl设置Ashmem大小
    ret = TEMP_FAILURE_RETRY(ioctl(fd, ASHMEM_SET_SIZE, size));
    if (ret < 0) {
        goto error;
    }

    return fd;

error:
    save_errno = errno;
    close(fd);
    errno = save_errno;
    return ret;
}
```

当`ashmem_create_region`打开/dev/ashmem节点成功后，调用mapfd将打开的fd节点映射到进程空间中，并分别将基地址，设备节点fd,地址偏移保存到mBase, mFD, mOffset中．mmap定义为`PROT_READ`,`PROT_WRITE`表明该地址能够被读写，且能够允许其他进程去共享该段内存映射(MAP_SHARED)．由此AudioTrack也应该能够通过该段内存去与AuidoFlinger通信．
```c++
status_t MemoryHeapBase::mapfd(int fd, size_t size, uint32_t offset)
{
    if (size == 0) {
        // try to figure out the size automatically
        struct stat sb;
        if (fstat(fd, &sb) == 0)
            size = sb.st_size;
        // if it didn't work, let mmap() fail.
    }

    if ((mFlags & DONT_MAP_LOCALLY) == 0) {
        //将AShmem设备映射到进程空间中
        void* base = (uint8_t*)mmap(0, size,
                PROT_READ|PROT_WRITE, MAP_SHARED, fd, offset);
        if (base == MAP_FAILED) {
            ALOGE("mmap(fd=%d, size=%u) failed (%s)",
                    fd, uint32_t(size), strerror(errno));
            close(fd);
            return -errno;
        }
        //ALOGD("mmap(fd=%d, base=%p, size=%lu)", fd, base, size);
        mBase = base;
        mNeedUnmap = true;
    } else  {
        mBase = 0; // not MAP_FAILED
        mNeedUnmap = false;
    }
    mFD = fd;
    mSize = size;
    mOffset = offset;
    return NO_ERROR;
}
```

```c++
//system/core/libcutils/ashmem-dev.cpp
int ashmem_set_prot_region(int fd, int prot)
{
    //确保该fd是通过打开ashmem节点获得的．
    int ret = __ashmem_is_ashmem(fd, 1);
    if (ret < 0) {
        return ret;
    }
    //通过ioctl设置匿名存储属性，初始化时prot传参为PROT_READ
    return TEMP_FAILURE_RETRY(ioctl(fd, ASHMEM_SET_PROT_MASK, prot));
}
```

小结:当新建AudioTrack后，，AudioFlinger会通过新建一个client保存客户端的信息，如pid，uid等,并将其加入Vector中进行管理． 随后AudioFlinger创建出一块匿名内存，映射到该设备节点中，之后AudioTrack如果也映射该节点，就可以实现匿名共享内存的通信．

## 3.5 AudioTrack映射Ashemem


在开展本节的学习前，首先给出类图方便理解：

![](/img/bill/in-posts/2019-04-15/1.png)

回到AudioTrack调用到`createTrack_l()`的流程，当AudioTrack通过Binder通信调用createTrack时，AudioFlinger完成了创建匿名共享内存的动作，之后AudioTrack是如何映射到同一个设备节点呢?答案在getCblk方法中．

```c++
//frameworks/av/media/libaudioclient/AudioTrack.cpp
status_t AudioTrack::createTrack_l()
{
...
    const sp<IAudioFlinger>& audioFlinger = AudioSystem::get_audio_flinger();
    //借助audioFlinger创建TrackHandle类型的对象，其有一个PlaybackThread的对象
    sp<IAudioTrack> track = audioFlinger->createTrack(input,
                                                  output,
                                                  &status);
    ...
    //通过Binder通信获取AudioFlinger中的内存映射信息,并映射到本进程
    sp<IMemory> iMem = track->getCblk();
    void *iMemPointer = iMem->pointer();
    ...
    mAudioTrack = track;
    mCblkMemory = iMem;
    ....
    audio_track_cblk_t* cblk = static_cast<audio_track_cblk_t*>(iMemPointer);
    mCblk = cblk;
    ...
}
```

audioFlinger调用createTrack后，在AudioFlinger中新建TrackHandle的对象，而TrackHandle构造方法中，必须传入一个PlaybackThread对象,即TrackHandle是PlaybackThread::Track的proxy端．TrackHandle的操作直接对接到PlaybackThread::Track对象中．返回给客户端这边的是BpAudioTrack对象.

```c++
//frameworks/av/services/audioflinger/AudioFlinger.h
class TrackHandle : public android::BnAudioTrack {
    public:
        explicit            TrackHandle(const sp<PlaybackThread::Track>& track);
        virtual             ~TrackHandle();
        virtual sp<IMemory> getCblk() const;
        virtual status_t    start();
        virtual void        stop();
        virtual void        flush();
        virtual void        pause();
        virtual status_t    attachAuxEffect(int effectId);
        virtual status_t    setParameters(const String8& keyValuePairs);
        virtual media::VolumeShaper::Status applyVolumeShaper(
                const sp<media::VolumeShaper::Configuration>& configuration,
                const sp<media::VolumeShaper::Operation>& operation) override;
        virtual sp<media::VolumeShaper::State> getVolumeShaperState(int id) override;
        virtual status_t    getTimestamp(AudioTimestamp& timestamp);
        virtual void        signal(); // signal playback thread for a change in control block

        virtual status_t onTransact(
            uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags);

    private:
        //维护一个PlaybackThread::Track对象，实际操作时，调用Track中的方法．
        const sp<PlaybackThread::Track> mTrack;
    };
```

相关的关系图如下:

![](/img/bill/in-posts/2019-04-15/2.png)

BpAudioTrack调用getCblk方法，通过binder通信获取到BpMemory对象cblk．

```c++
//frameworks/av/media//libaudioclient/IAudioTrack.cpp
virtual sp<IMemory> getCblk() const
    {
        Parcel data, reply;
        sp<IMemory> cblk;
        data.writeInterfaceToken(IAudioTrack::getInterfaceDescriptor());
        status_t status = remote()->transact(GET_CBLK, data, &reply);
        if (status == NO_ERROR) {
            //获取到bpMemory对象,用以向服务端发出请求．
            cblk = interface_cast<IMemory>(reply.readStrongBinder());
            if (cblk != 0 && cblk->pointer() == NULL) {
                cblk.clear();
            }
        }
        return cblk;
    }
```


BnAudioTrack收到请求后，解析请求`GET_CBLK`,并调用PlaybackThread::Track的父类TrackBase方法getCblk()来处理:

```c++
//frameworks/av/media//libaudioclient/IAudioTrack.cpp
status_t BnAudioTrack::onTransact(
    uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags)
{
    switch (code) {
        case GET_CBLK: {
            CHECK_INTERFACE(IAudioTrack, data, reply);
            //调用服务端的getCblk方法处理
            reply->writeStrongBinder(IInterface::asBinder(getCblk()));
            return NO_ERROR;
        } break;
    ....
}
```

mCblkMemory是IMemory类，实质为BnMemory类,通过asBinder方法，写进reply中为通信对象Binder.

```c++
//frameworks/av/services/audioflinger/TrackBase.h
sp<IMemory>         mCblkMemory;
...
class TrackBase : public ExtendedAudioBufferProvider, public RefBase {
public:
    ...
    sp<IMemory> getCblk() const { return mCblkMemory; }
    ...
}
```

由此在客户端中通过读取reply内容时，读取出来的正是IBinder对象，通过`interface_cast`获取BpMemory代理端．

```c++
cblk = interface_cast<IMemory>(reply.readStrongBinder());
```

BpMemory有方法getMemory能够获取通过Binder通信获取IMemoryHeap类型的对象，这里指的应当是AudioFligner创建的MemoryHeapBase.


那么mCblkMemory是在什么阶段创建的呢？答案是在TrackBase中进行初始化的，如下:

```c++
//frameworks/av/services/audioflinger/Tracks.cpp
AudioFlinger::ThreadBase::TrackBase::TrackBase(...){
...
    //client调用heap最终返回AudioFlinger::Client的mMemoryDealer对象
    mCblkMemory = client->heap()->allocate(size);
        if (mCblkMemory == 0 ||
                (mCblk = static_cast<audio_track_cblk_t *>(mCblkMemory->pointer())) == NULL) {
            ALOGE("not enough memory for AudioTrack size=%zu", size);
            client->heap()->dump("AudioTrack");
            mCblkMemory.clear();
            return;
        }
...
}
```

allocate返回的是一个Allocation对象，其中传入了MemoryDealer对象，MemoryHeapBase对象，以及计算出来的offset和size.其中MemoryHeapDealer对象正是之前在AudioFlinger中创建内存对象，保存了创建匿名共享内存的基地址，偏移以及大小．

```c++
//frameworks/native/libs/binder/MemoryDealer.cpp
sp<IMemory> MemoryDealer::allocate(size_t size)
{
    sp<IMemory> memory;
    const ssize_t offset = allocator()->allocate(size);
    if (offset >= 0) {
        memory = new Allocation(this, heap(), offset, size);
    }
    return memory;
}
```

在Allocation继承了MemoryBase，而MemoryBase又继承了BnMemory，可以看作是匿名共享内存的服务端．
```c++
//frameworks/native/libs/binder/MemoryDealer.cpp
Allocation::Allocation(
        const sp<MemoryDealer>& dealer,
        const sp<IMemoryHeap>& heap, ssize_t offset, size_t size)
    : MemoryBase(heap, offset, size), mDealer(dealer)
{
#ifndef NDEBUG
    void* const start_ptr = (void*)(intptr_t(heap->base()) + offset);
    memset(start_ptr, 0xda, size);
#endif
}
```

至此，我们知道了iMem为BpMemory对象，且客户端AudioTrack仍未进行内存映射，将继续研究pointer的实现逻辑:

```c++
    sp<IMemory> iMem = track->getCblk();
    void *iMemPointer = iMem->pointer();
```

```c++
//frameworks/native/libs/binder/IMemory.cpp
void* IMemory::pointer() const {
    ssize_t offset;
    //调用BpMemory的getMemory方法
    sp<IMemoryHeap> heap = getMemory(&offset);
    void* const base = heap!=0 ? heap->base() : MAP_FAILED;
    if (base == MAP_FAILED)
        return 0;
    return static_cast<char*>(base) + offset;
}
```

getMemory的实质是获取了BpMemoryHeap,从而可以通过BpMemoryHeap与MemoryHeapBase(BnMemoryHeap)进行通信．
```c++
//frameworks/native/libs/binder/IMemory.cpp
sp<IMemoryHeap> BpMemory::getMemory(ssize_t* offset, size_t* size) const
{
    if (mHeap == 0) {
        Parcel data, reply;
        data.writeInterfaceToken(IMemory::getInterfaceDescriptor());
        if (remote()->transact(GET_MEMORY, data, &reply) == NO_ERROR) {
            sp<IBinder> heap = reply.readStrongBinder();
            ssize_t o = reply.readInt32();
            size_t s = reply.readInt32();
            if (heap != 0) {
                //获得了BpMemoryHeap代理端
                mHeap = interface_cast<IMemoryHeap>(heap);
                if (mHeap != 0) {
                    size_t heapSize = mHeap->getSize();
                    if (s <= heapSize
                            && o >= 0
                            && (static_cast<size_t>(o) <= heapSize - s)) {
                        mOffset = o;
                        mSize = s;
                    } else {
                        // Hm.
                        android_errorWriteWithInfoLog(0x534e4554,
                            "26877992", -1, NULL, 0);
                        mOffset = 0;
                        mSize = 0;
                    }
                }
            }
        }
    }
    if (offset) *offset = mOffset;
    if (size) *size = mSize;
    return (mSize > 0) ? mHeap : 0;
}
```

当pointer调用完getMemory(&offset)获得BpMemoryHeap后，马上调用base()方法(BpMemoryHeap父类IMemoryHeap的方法)，向MemoryHeapBase通信:

```c++
//frameworks/native/libs/binder/include/binder/IMemory.h
class IMemoryHeap : public IInterface
{
public:
    ...
    void*   base() const  { return getBase(); }
    ...
};
```

```c++
//frameworks/native/libs/binder/include/binder/IMemory.cpp
void* BpMemoryHeap::getBase() const {
    assertMapped();
    return mBase;
}
```


```c++
//frameworks/native/libs/binder/include/binder/IMemory.cpp
void BpMemoryHeap::assertMapped() const
{
    int32_t heapId = mHeapId.load(memory_order_acquire);
    if (heapId == -1) {
        sp<IBinder> binder(IInterface::asBinder(const_cast<BpMemoryHeap*>(this)));
        sp<BpMemoryHeap> heap(static_cast<BpMemoryHeap*>(find_heap(binder).get()));
        //完成实际映射操作
        heap->assertReallyMapped();
        if (heap->mBase != MAP_FAILED) {
            Mutex::Autolock _l(mLock);
            if (mHeapId.load(memory_order_relaxed) == -1) {
                mBase   = heap->mBase;
                mSize   = heap->mSize;
                mOffset = heap->mOffset;
                int fd = fcntl(heap->mHeapId.load(memory_order_relaxed), F_DUPFD_CLOEXEC, 0);
                ALOGE_IF(fd==-1, "cannot dup fd=%d",
                        heap->mHeapId.load(memory_order_relaxed));
                mHeapId.store(fd, memory_order_release);
            }
        } else {
            // something went wrong
            free_heap(binder);
        }
    }
}
```

```c++
//frameworks/native/libs/binder/include/binder/IMemory.cpp
void BpMemoryHeap::assertReallyMapped() const
{
    int32_t heapId = mHeapId.load(memory_order_acquire);
    //初次映射内存
    if (heapId == -1) {

        // remote call without mLock held, worse case scenario, we end up
        // calling transact() from multiple threads, but that's not a problem,
        // only mmap below must be in the critical section.

        Parcel data, reply;
        data.writeInterfaceToken(IMemoryHeap::getInterfaceDescriptor());
        //要求BnMemoryHeap返回fd,size等数据
        status_t err = remote()->transact(HEAP_ID, data, &reply);
        //获取AudioFlinger中创建ashmem的fd
        int parcel_fd = reply.readFileDescriptor();
        ssize_t size = reply.readInt32();
        uint32_t flags = reply.readInt32();
        uint32_t offset = reply.readInt32();

        ALOGE_IF(err, "binder=%p transaction failed fd=%d, size=%zd, err=%d (%s)",
                IInterface::asBinder(this).get(),
                parcel_fd, size, err, strerror(-err));

        Mutex::Autolock _l(mLock);
        if (mHeapId.load(memory_order_relaxed) == -1) {
            int fd = fcntl(parcel_fd, F_DUPFD_CLOEXEC, 0);
            ALOGE_IF(fd==-1, "cannot dup fd=%d, size=%zd, err=%d (%s)",
                    parcel_fd, size, err, strerror(errno));

            int access = PROT_READ;
            if (!(flags & READ_ONLY)) {
                access |= PROT_WRITE;
            }
            mRealHeap = true;
            //将设备节点fd映射到进程用户空间中,由此完成AudioTrack与AudioFlinger匿名共享内存．
            mBase = mmap(0, size, access, MAP_SHARED, fd, offset);
            if (mBase == MAP_FAILED) {
                ALOGE("cannot map BpMemoryHeap (binder=%p), size=%zd, fd=%d (%s)",
                        IInterface::asBinder(this).get(), size, fd, strerror(errno));
                close(fd);
            } else {
                mSize = size;
                mFlags = flags;
                mOffset = offset;
                mHeapId.store(fd, memory_order_release);
            }
        }
    }
}
```


```c++
status_t BnMemoryHeap::onTransact(
        uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags)
{
    switch(code) {
       case HEAP_ID: {
            CHECK_INTERFACE(IMemoryHeap, data, reply);
            reply->writeFileDescriptor(getHeapID());
            reply->writeInt32(getSize());
            reply->writeInt32(getFlags());
            reply->writeInt32(getOffset());
            return NO_ERROR;
        } break;
        default:
            return BBinder::onTransact(code, data, reply, flags);
    }
}
```

服务端MemoryHeapBase返回的是AudioFlinger中创建匿名共享内存的信息．
```c++
int MemoryHeapBase::getHeapID() const {
    return mFD;
}

void* MemoryHeapBase::getBase() const {
    return mBase;
}

size_t MemoryHeapBase::getSize() const {
    return mSize;
}

uint32_t MemoryHeapBase::getFlags() const {
    return mFlags;
}

```

最后pointer返回的地址为`static_cast<char*>(base) + offset;`,并强制转换为`audio_track_cblk_t`.可得知AudioTrack和AudioFlinger费煞苦心，就是为了`audio_track_cblk_t`的通信．这部分内容将会在后续的Audio学习中研究．

```c++
//frameworks/av/media/libaudioclient/AudioTrack.cpp
    audio_track_cblk_t* cblk = static_cast<audio_track_cblk_t*>(iMemPointer);
    mCblk = cblk;
```

