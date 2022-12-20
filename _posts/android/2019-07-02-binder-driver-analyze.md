---
layout:     post
title:      "Android Binder驱动简析"
summary:    '"Android Binder"'
date:       2019-07-02 16:54:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-07-02.jpg"
catalog: true
tags:
    - android
    - Binder
---


<!-- vim-markdown-toc GFM -->

* [1. Binder 数据结构](#1-binder-数据结构)
* [2. Binder操作](#2-binder操作)
	* [2.1 `binder_init`](#21-binder_init)
		* [2.1.1 `binder_init`](#211-binder_init)
		* [2.1.2 `init_binder_device`](#212-init_binder_device)
	* [2.2 `binder_open`](#22-binder_open)
	* [2.3 `binder_mmap`](#23-binder_mmap)
	* [2.4 `binder_ioctl`](#24-binder_ioctl)
	* [2.5 `service_manager`的注册过程](#25-service_manager的注册过程)
	* [2.6 binder服务的注册过程](#26-binder服务的注册过程)
	* [2.7 binder代理端通信流程](#27-binder代理端通信流程)
		* [2.7.1 `BC_ENTER_LOOPER`](#271-bc_enter_looper)
		* [2.7.2 `BC_TRANSACTION`](#272-bc_transaction)
		* [2.7.3 `BR_TRANSACTION_COMPLETE && BR_TRANSACTION`](#273-br_transaction_complete--br_transaction)
		* [2.7.4 `BC_REPLY && BR_TRANSACTION_COMPLETE`](#274-bc_reply--br_transaction_complete)
		* [2.7.5 BR_REPLY](#275-br_reply)

<!-- vim-markdown-toc -->

# 1. Binder 数据结构

![](/img/bill/in-posts/2019-07-02/binder-structure.png)


# 2. Binder操作

首先明确本文以linux4.9以及Android P为分析平台，如下分析均基于开源源码进行分析.


## 2.1 `binder_init`

### 2.1.1 `binder_init`


```c
//linux-4.9/drivers/android/binder.c
static int __init binder_init(void)
{
	int ret;
	char *device_name, *device_names;
	struct binder_device *device;
	struct hlist_node *tmp;

	binder_alloc_shrinker_init();

	atomic_set(&binder_transaction_log.cur, ~0U);
	atomic_set(&binder_transaction_log_failed.cur, ~0U);
    //在debugfs下创建了binder目录，即/sys/kernel/debug/binder
	binder_debugfs_dir_entry_root = debugfs_create_dir("binder", NULL);
	//在binder目录下创建了proc目录,即/sys/kernel/debug/binder/proc
	if (binder_debugfs_dir_entry_root)
		binder_debugfs_dir_entry_proc = debugfs_create_dir("proc",
						 binder_debugfs_dir_entry_root);
    //又在binder目录下创建了文件state,stats,transactions,transaciton_log,failed_transaction_log
    //通过这五个文件读取Binder驱动程序的运行状况
	if (binder_debugfs_dir_entry_root) {
		debugfs_create_file("state",
				    S_IRUGO,
				    binder_debugfs_dir_entry_root,
				    NULL,
				    &binder_state_fops);
		debugfs_create_file("stats",
				    S_IRUGO,
				    binder_debugfs_dir_entry_root,
				    NULL,
				    &binder_stats_fops);
		debugfs_create_file("transactions",
				    S_IRUGO,
				    binder_debugfs_dir_entry_root,
				    NULL,
				    &binder_transactions_fops);
		debugfs_create_file("transaction_log",
				    S_IRUGO,
				    binder_debugfs_dir_entry_root,
				    &binder_transaction_log,
				    &binder_transaction_log_fops);
		debugfs_create_file("failed_transaction_log",
				    S_IRUGO,
				    binder_debugfs_dir_entry_root,
				    &binder_transaction_log_failed,
				    &binder_transaction_log_fops);
	}
    //device_names的内容为"binder,hwbinder,vndbinder"	
	device_names = kzalloc(strlen(binder_devices_param) + 1, GFP_KERNEL);
	if (!device_names) {
		ret = -ENOMEM;
		goto err_alloc_device_names_failed;
	}
	strcpy(device_names, binder_devices_param);
    //分别去对上述三个binder进行初始化，调用init_binder_device
	while ((device_name = strsep(&device_names, ","))) {
		ret = init_binder_device(device_name);
		if (ret)
			goto err_init_binder_device_failed;
	}

	return ret;

err_init_binder_device_failed:
	hlist_for_each_entry_safe(device, tmp, &binder_devices, hlist) {
		misc_deregister(&device->miscdev);
		hlist_del(&device->hlist);
		kfree(device);
	}
err_alloc_device_names_failed:
	debugfs_remove_recursive(binder_debugfs_dir_entry_root);

	return ret;
}

device_initcall(binder_init);
```

binder驱动在初始化时，首先会调用`binder_init`初始化。开机后，可以通过查看`/sys/kernel/debug/binder`查看新建了`state,stats,transactions,transaction_log,failed_transaction_log`文件，以及一个proc目录。其中proc目录中都是进程号，观察其中的进程都是注册在驱动的进程，其中包括servicemanager。打开其中一个为例,1754为audioserver进程，可以将其分为三部分看:

```
# cat /sys/kernel/debug/binder/proc/1754
binder proc state:
proc 1754
context binder # binder上下文
# threads信息
  thread 1754: l 12 need_return 0 tr 0
  thread 1940: l 12 need_return 0 tr 0
  thread 1941: l 11 need_return 0 tr 0
  thread 1962: l 00 need_return 0 tr 0
  thread 4020: l 11 need_return 0 tr 0
# nodes信息
  node 57057: u00000000efdb9050 c00000000f0614870 pri 0:139 hs 1 hw 1 ls 0 lw 0 is 1 iw 1 tr 1 proc 1921
  node 910: u00000000f0618230 c00000000f066a004 pri 0:139 hs 1 hw 1 ls 0 lw 0 is 4 iw 4 tr 1 proc 1803 2140 1921 1648
  node 2949: u00000000f06183b0 c00000000f0613184 pri 0:139 hs 1 hw 1 ls 0 lw 0 is 4 iw 4 tr 1 proc 1803 2140 1921 1648
  node 2941: u00000000f0618b90 c00000000f062a444 pri 0:139 hs 1 hw 1 ls 0 lw 0 is 1 iw 1 tr 1 proc 1921
  node 2972: u00000000f0618c10 c00000000f061dff4 pri 0:139 hs 1 hw 1 ls 0 lw 0 is 2 iw 2 tr 1 proc 1921 1648
  node 58001: u00000000f0618e90 c00000000f0649f34 pri 0:139 hs 1 hw 1 ls 0 lw 0 is 1 iw 1 tr 1 proc 1803
  node 57997: u00000000f0618ee0 c00000000f062c464 pri 0:139 hs 1 hw 1 ls 0 lw 0 is 1 iw 1 tr 1 proc 1803
  node 57993: u00000000f0618f10 c00000000f061cd24 pri 0:139 hs 1 hw 1 ls 0 lw 0 is 1 iw 1 tr 1 proc 1803
# refs信息
  ref 871: desc 0 node 1 s 1 w 1 d 0000000000000000
  ref 2939: desc 1 node 2857 s 0 w 1 d 0000000000000000
  ref 3975: desc 2 node 3974 s 1 w 1 d 0000000000000000
  ref 3984: desc 3 node 2909 s 1 w 1 d 0000000000000000
  ref 4001: desc 4 node 4000 s 1 w 1 d 0000000000000000
  ref 58241: desc 5 node 1858 s 1 w 1 d 0000000000000000
  ref 16360: desc 6 node 16359 s 1 w 1 d 0000000000000000
  ref 57045: desc 7 node 57044 s 1 w 1 d 0000000000000000
  ref 57054: desc 8 node 1884 s 1 w 1 d 0000000000000000
  ref 57751: desc 9 node 57750 s 1 w 1 d 0000000000000000
  ref 57970: desc 10 node 57969 s 1 w 1 d 0000000000000000
binder proc state:
proc 1754
context hwbinder # hwbinder相关上下文
  thread 1754: l 00 need_return 0 tr 0
  thread 1934: l 12 need_return 0 tr 0
  thread 1937: l 00 need_return 0 tr 0
  thread 1939: l 11 need_return 0 tr 0
  thread 1941: l 00 need_return 0 tr 0
  thread 1962: l 00 need_return 0 tr 0
  ref 874: desc 0 node 2 s 1 w 1 d 0000000000000000
  ref 886: desc 1 node 273 s 1 w 1 d 0000000000000000
  ref 906: desc 2 node 384 s 1 w 1 d 0000000000000000
  ref 991: desc 3 node 990 s 1 w 1 d 0000000000000000
  ref 1009: desc 4 node 1008 s 1 w 1 d 0000000000000000
  ref 1545: desc 5 node 1544 s 1 w 1 d 0000000000000000
  ref 1555: desc 6 node 1554 s 1 w 1 d 0000000000000000
  ref 2966: desc 7 node 427 s 1 w 1 d 0000000000000000
  buffer 7333: 0000000000000000 size 8:0:0 delivered
  buffer 1090: 0000000000000000 size 8:0:0 delivered
  buffer 63851: 0000000000000000 size 8:0:0 delivered
  buffer 57991: 0000000000000000 size 8:0:0 delivered
```

1.**`线程信息`**

从这份进程的binder信息可以看出，该进程有多少个线程:1754主线程以及1940,1941,1962,4020,可以通过`ps -t|grep 1754`验证:

```
audioserver   1754  1754     1   46268  16548 binder_thread_read  0 S audioserver
audioserver   1754  1934     1   46268  16548 binder_thread_read  0 S HwBinder:1754_1
audioserver   1754  1936     1   46268  16548 futex_wait_queue_me 0 S ApmTone
audioserver   1754  1937     1   46268  16548 futex_wait_queue_me 0 S ApmAudio
audioserver   1754  1938     1   46268  16548 futex_wait_queue_me 0 S ApmOutput
audioserver   1754  1939     1   46268  16548 binder_thread_read  0 S HwBinder:1754_2
audioserver   1754  1940     1   46268  16548 binder_thread_read  0 S Binder:1754_1
audioserver   1754  1941     1   46268  16548 binder_thread_read  0 S Binder:1754_2
audioserver   1754  1962     1   46268  16548 futex_wait_queue_me 0 S AudioOut_D
audioserver   1754  2062     1   46268  16548 futex_wait_queue_me 0 S soundTrigger cb
audioserver   1754  2093     1   46268  16548 futex_wait_queue_me 0 S TimeCheckThread
audioserver   1754  4020     1   46268  16548 binder_thread_read  0 S Binder:1754_3
```

可以看出，audioserver中维护的线程应该对应`binder_proc`结构体的线程红黑树threads,均用于binder通信。其格式可以看出:

```
#线程id为1754, l代表looper，即线程状态，线程状态是BINDER_LOOPER_STATE_ENTERED,BINDER_LOOPER_STATE_WAITING。
# tr即tmp_ref，表明线程是否正在使用
thread 1754: l 12 need_return 0 tr 0
```

下图为looper状态:

```
BINDER_LOOPER_STATE_REGISTERED  = 0x01,
BINDER_LOOPER_STATE_ENTERED     = 0x02,
BINDER_LOOPER_STATE_EXITED      = 0x04,
BINDER_LOOPER_STATE_INVALID     = 0x08,
BINDER_LOOPER_STATE_WAITING     = 0x10,
BINDER_LOOPER_STATE_POLL        = 0x20,
```

2.**node信息**

```
node 57057: u00000000efdb9050 c00000000f0614870 pri 0:139 hs 1 hw 1 ls 0 lw 0 is 1 iw 1 tr 1 proc 1921
```

node会打印包括
`debug_id`(57057),Server服务的地址，IBinder地址(u00000000efdb9050),`weakref_impl`地址(c00000000f0614870),策略(0,即SCHED_NOMRAL),最低优先级(139),`has_strong_ref`(1),`has_weak_ref`(1),`local_strong_ref`(0),
`local_weak_refs`(0),`internal_strong_refs`(1),`refs`的个数(1)以及节点是否正在使用(1)。最后打印所有`binder_node`维护的`binder_refs`。本例就是1921进程(`system_server`)与`binder_node` 57057进行了Binder通信。

当运行`cat /sys/kernel/debug/binder/proc/1754`后，会遍历1754的binder进程的红黑树nodes，将所有的`binder_node`都打印出来。当上层在传输过程中调用了writeStrongBinder/writeWeakBinder，就会将binder对象信息，如`weakref_impl`地址，IBinder地址存放在`flat_binder_object`中，驱动解析时，就会首先找红黑树nodes是否存在以`weakref_impl`地址为关键字的节点，假如找不到，就会调用`binder_new_node`创建新节点，由此形成了红黑树nodes。


3.**ref信息**
```
ref 871: desc 0 node 1 s 1 w 1 d 0000000000000000
```
ref信息会打印包括`debug_id`,desc(0)，如果是存活的打印node,否则打印deadnode,后面是ref对应的node的`debug_id`,强引用计数(1),弱引用计数(1)以及指向死亡通知的地址。

进程的红黑树desc记录的是handle值，当需要增加`binder_node`或者`binder_proc`的引用时，比如当传输binder服务或者代理时，或者上层调用了incWeakHandle时(BpBinder构造时会调用，所以说`binder_ref`代表了proxy端)，假如红黑树中不存在对应的节点，都会使得红黑树desc中增加新的`binder_ref`。cat后打印出的ref列表即为进程1754的所有proxy端。

至于其他节点，可以简单总结如下:

```
/sys/kernel/debug/binder/state (整体以及各个进程的thread/node/ref/buffer的状态信息,如有deadnode也会打印)
/sys/kernel/debug/binder/stats (整体以及各个进程的线程数,事务个数等的统计信息)
/sys/kernel/debug/binder/failed_transaction_log (记录32条最近的传输失败事件)
/sys/kernel/debug/binder/transaction_log (记录32条最近的传输事件)
/sys/kernel/debug/binder/transactions (遍历所有进程的buffer分配情况)
```

### 2.1.2 `init_binder_device`

从`binder_init`传入的name分别为binder,hwbinder,vndbinder,对应每一个设备，都会有一个结构体`binder_device`进行描述。

```c
//linux-4.9/drivers/android/binder.c
struct binder_device {
	struct hlist_node hlist;//用以加入binder_devices全局链表
	struct miscdevice miscdev;//misc设备
	struct binder_context context;//可以用来获取ServiceManager对应的binder_node
};
```

```c
//linux-4.9/drivers/android/binder.c
static int __init init_binder_device(const char *name)
{
	int ret;
	struct binder_device *binder_device;

	binder_device = kzalloc(sizeof(*binder_device), GFP_KERNEL);
	if (!binder_device)
		return -ENOMEM;
    //定义binder设备操作方法fops
	binder_device->miscdev.fops = &binder_fops;
	binder_device->miscdev.minor = MISC_DYNAMIC_MINOR;
	binder_device->miscdev.name = name;

	binder_device->context.binder_context_mgr_uid = INVALID_UID;
	binder_device->context.name = name;
	mutex_init(&binder_device->context.context_mgr_node_lock);
    //注册misc设备,注册后在/sys/devices/virtual/misc目录下可以看到binder
	ret = misc_register(&binder_device->miscdev);
	if (ret < 0) {
		kfree(binder_device);
		return ret;
	}
    //将该binder_device通过bidner_devices全局链表进行管理，现在看来驱动会维护一个全局链表维护所有binder设备
	hlist_add_head(&binder_device->hlist, &binder_devices);
	return ret;
}
```

`binder_fops`定义了设备文件的操作方法，后续将会根据以下方法一一展开学习。
```c
static const struct file_operations binder_fops = {
	.owner = THIS_MODULE,
	.poll = binder_poll,
	.unlocked_ioctl = binder_ioctl,
	.compat_ioctl = binder_ioctl,
	.mmap = binder_mmap,
	.open = binder_open,
	.flush = binder_flush,
	.release = binder_release,
};
```

## 2.2 `binder_open`

`binder_open`对接到了上层的open，在Native层ProcessState初始化时会调用`open_driver`,并会主动打开binder驱动，即调用到了这里的`binder_open`。

```c
//linux-4.9/drivers/android/binder.c
static int binder_open(struct inode *nodp, struct file *filp)
{
	struct binder_proc *proc;
	struct binder_device *binder_dev;
    ...
    //当打开Binder节点时，会创建一个binder_proc描述为binde进程
	//为biner_proc分配内存
	proc = kzalloc(sizeof(*proc), GFP_KERNEL);
	if (proc == NULL)
		return -ENOMEM;
	//初始化两个自旋锁,其中inner_lock用来保护线程以及binder_node以及所有与进程相关的的todo队列
	//outer_lock保护binder_ref
	spin_lock_init(&proc->inner_lock);
	spin_lock_init(&proc->outer_lock);
	//获取当前进程组的进程组领头进程group_leader,并赋值到proc中
	get_task_struct(current->group_leader);
	proc->tsk = current->group_leader;
	//初始化proc的todo列表
	INIT_LIST_HEAD(&proc->todo);
	//判断当前进程的调度策略是否支持，binder只支持SCHED_NORMAL,SCHED_BATCH,SCHED_FIFO,SCHED_RR。
	//prio为进程优先级，可通过normal_prio获取。一般分为实时优先级(实时进程)以及静态优先级(非实时进程)
	if (binder_supported_policy(current->policy)) {
		proc->default_priority.sched_policy = current->policy;
		proc->default_priority.prio = current->normal_prio;
	} else {
		proc->default_priority.sched_policy = SCHED_NORMAL;
		proc->default_priority.prio = NICE_TO_PRIO(0);
	}
    //通过miscdev获取binder_device
	binder_dev = container_of(filp->private_data, struct binder_device,
				  miscdev);
	proc->context = &binder_dev->context;
	//初始化binder_proc的成员结构体binder_alloc
	binder_alloc_init(&proc->alloc);
    //binder驱动维护静态全局数组biner_stats，其中有一个成员数组obj_created,
    //当binder_open调用时，obj_created[BINDER_STAT_PROC]将自增。该数组用来统计binder对象的数量。
	binder_stats_created(BINDER_STAT_PROC);
	//初始化binder_proc的pid,为当前领头进程的pid值
	proc->pid = current->group_leader->pid;
	//初始化delivered_death以及waiting_threads队列
	INIT_LIST_HEAD(&proc->delivered_death);
	INIT_LIST_HEAD(&proc->waiting_threads);
	//private_data保存binder_proc类型的对象
	filp->private_data = proc;
    //将binder_proc加入到全局队列binder_procs中,该操作必须加锁(全局变量)
	mutex_lock(&binder_procs_lock);
	hlist_add_head(&proc->proc_node, &binder_procs);
	mutex_unlock(&binder_procs_lock);
    //假如/binder/proc目录已经创建好，在该目录下创建一个以pid为名的文件
	if (binder_debugfs_dir_entry_proc) {
		char strbuf[11];
		snprintf(strbuf, sizeof(strbuf), "%u", proc->pid);
		proc->debugfs_entry = debugfs_create_file(strbuf, S_IRUGO,
			binder_debugfs_dir_entry_proc,
			(void *)(unsigned long)proc->pid,
			&binder_proc_fops);
	}
	return 0;
}
```

关于linux调度策略可参考如下:

![](/img/bill/in-posts/2019-07-02/linux_policy.png)

## 2.3 `binder_mmap` 

当上层调用mmap将/dev/binder/映射到自己的空间时，

```c
//linux-4.9/drivers/android/binder.c
static int binder_mmap(struct file *filp, struct vm_area_struct *vma)
{
	int ret;
	//private_data保存的是binder_proc进程相关的结构体
	struct binder_proc *proc = filp->private_data;
	const char *failure_string;

	if (proc->tsk != current->group_leader)
		return -EINVAL;
    //限定映射的用户空间范围必须要在4M以内，vma(vm_area_struct类型)描述的是用户空间地址
	if ((vma->vm_end - vma->vm_start) > SZ_4M)
		vma->vm_end = vma->vm_start + SZ_4M;
    ...
    //FORBIDDEN_MMAP_FLAGS即写的flag，用户申请映射的空间只能够读，因此如果有写的flag，就会报错。
	if (vma->vm_flags & FORBIDDEN_MMAP_FLAGS) {
		ret = -EPERM;
		failure_string = "bad vm_flags";
		goto err_bad_arg;
	}
	//定义除了不能够写，还不能够拷贝(VM_DONTCOPY)而且禁止可能会执行写操作的标志位
	vma->vm_flags = (vma->vm_flags | VM_DONTCOPY) & ~VM_MAYWRITE;
	vma->vm_ops = &binder_vm_ops;
	vma->vm_private_data = proc;
    //调用binder_alloc_mmap_handler分配映射内存
	ret = binder_alloc_mmap_handler(&proc->alloc, vma);

	return ret;

err_bad_arg:
	...
	return ret;
}

//linux-4.9/drivers/android/binder_alloc.c
int binder_alloc_mmap_handler(struct binder_alloc *alloc,
			      struct vm_area_struct *vma)
{
	int ret;
	struct vm_struct *area;
	const char *failure_string;
	struct binder_buffer *buffer;
    //分配buffer时需要上锁binder_alloc_mmap_lock
	mutex_lock(&binder_alloc_mmap_lock);
	if (alloc->buffer) {
		ret = -EBUSY;
		failure_string = "already mapped";
		goto err_already_mapped;
	}
    //在进程的内核空间分配大小为vma->vm_end - vma->vm_start的连续的空间。
	area = get_vm_area(vma->vm_end - vma->vm_start, VM_IOREMAP);
	if (area == NULL) {
		ret = -ENOMEM;
		failure_string = "get_vm_area";
		goto err_get_vm_area_failed;
	}
	//binder_alloc的buffer指向内核空间地址
	alloc->buffer = area->addr;
	//vma->vm_start为用户空间起始地址，alloc->buffer为内核空间起始地址
	//用户空间地址与内核空间地址的差值保存在user_buffer_offset中。
	alloc->user_buffer_offset =
		vma->vm_start - (uintptr_t)alloc->buffer;
	mutex_unlock(&binder_alloc_mmap_lock);
    ...
    //pages管理的是物理页，这里分配了长度为(vma->vm_end - vma->vm_start) / PAGE_SIZE)，
    //单位是sizeof(alloc->pages[0])的数组，pages指向其起始地址。
	alloc->pages = kzalloc(sizeof(alloc->pages[0]) *
				   ((vma->vm_end - vma->vm_start) / PAGE_SIZE),
			       GFP_KERNEL);
	if (alloc->pages == NULL) {
		ret = -ENOMEM;
		failure_string = "alloc page array";
		goto err_alloc_pages_failed;
	}
	//buffer_size是通过get_vm_area分配的内核空间的大小
	alloc->buffer_size = vma->vm_end - vma->vm_start;
    //分配了一个binder_buffer的结构体
	buffer = kzalloc(sizeof(*buffer), GFP_KERNEL);
	if (!buffer) {
		ret = -ENOMEM;
		failure_string = "alloc buffer struct";
		goto err_alloc_buf_struct_failed;
	}
    //buffer的data指针指向alloc的内核空间缓冲区地址
	buffer->data = alloc->buffer;
	//将buffer加入到binder_alloc中的内核缓冲链表中管理
	list_add(&buffer->entry, &alloc->buffers);
	buffer->free = 1;
	//该buffer未被使用，因此调用binder_insert_free_buffer
	//使用free_buffers红黑树进行管理
	binder_insert_free_buffer(alloc, buffer);
	//将最大可用于异步事务的内核缓冲区大小设置为内核缓冲区大小的一半
	alloc->free_async_space = alloc->buffer_size / 2;
	barrier();
	//描述用户空间的vma
	alloc->vma = vma;
	alloc->vma_vm_mm = vma->vm_mm;
	atomic_inc(&alloc->vma_vm_mm->mm_count);

	return 0;

err_alloc_buf_struct_failed:
	kfree(alloc->pages);
	alloc->pages = NULL;
err_alloc_pages_failed:
	mutex_lock(&binder_alloc_mmap_lock);
	vfree(alloc->buffer);
	alloc->buffer = NULL;
err_get_vm_area_failed:
err_already_mapped:
	mutex_unlock(&binder_alloc_mmap_lock);
	...
	return ret;
}
```

`binder_insert_free_buffer`是用于将`binder_alloc`对象插入到进程中的红黑树中。

```c
//linux-4.9/drivers/android/binder_alloc.c
static void binder_insert_free_buffer(struct binder_alloc *alloc,
				      struct binder_buffer *new_buffer)
{
    //获取Binder进程的红黑树根节点
	struct rb_node **p = &alloc->free_buffers.rb_node;
	struct rb_node *parent = NULL;
	struct binder_buffer *buffer;
	size_t buffer_size;
	size_t new_buffer_size;
    //通过binder_alloc_buffer_size计算当前new_buffer的大小，之后将用于比较。
	new_buffer_size = binder_alloc_buffer_size(alloc, new_buffer);
	...
	while (*p) {
		parent = *p;
		//获取当前红黑树节点的buffer
		buffer = rb_entry(parent, struct binder_buffer, rb_node);
        //计算当前红黑树节点的buffer大小
		buffer_size = binder_alloc_buffer_size(alloc, buffer);
        //红黑树遵循二叉树规则,当新的buffer比当前节点的buffer小时
        //向左子节点继续重复，否则去右子节点.
		if (new_buffer_size < buffer_size)
			p = &parent->rb_left;
		else
			p = &parent->rb_right;
	}
	//找到合适位置后，将new_buffer插入到该位置。
	rb_link_node(&new_buffer->rb_node, parent, p);
	rb_insert_color(&new_buffer->rb_node, &alloc->free_buffers);
}

//该方法是给定新建的buffer，来算出buffer的大小。
static size_t binder_alloc_buffer_size(struct binder_alloc *alloc,
				       struct binder_buffer *buffer)
{
    //binder进程中的binder_alloc成员管理着一个内核缓冲区链表
    //首先检查这个新的buffer(肯定会加入到链表中的)是在链表末尾。
    //所以buffer大小为:基地址(alloc->buffer，总的缓冲区内核起始地址)加上总大小(alloc->buffer_size,
    //映射的总大小),计算出尾部的地址，再减去当前buffer的内核地址(buffer->data,当前buffer的起始地址)
	if (list_is_last(&buffer->entry, &alloc->buffers))
		return (u8 *)alloc->buffer +
			alloc->buffer_size - (u8 *)buffer->data;
	//假如不是在尾部，则用下一个的buffer的内核地址减去当前buffer的内核地址
	return (u8 *)binder_buffer_next(buffer)->data - (u8 *)buffer->data;
}
```

到这里只是分配了内核的连续内存以及物理内存，但并没有进行实际映射。事实上在调用`binder_transaction`函数时，才会实际建立映射，因为其中会运行：

```c
//linux-4.9/drivers/android/binder.c
    //t为bidner_transaction_data	
	t->buffer = binder_alloc_new_buf(&target_proc->alloc, tr->data_size,
		tr->offsets_size, extra_buffers_size,
    		!reply && (t->flags & TF_ONE_WAY));
```

```c
//linux-4.9/drivers/android/binder_alloc.c
//分配一个新的binder_buffer对象并返回。
struct binder_buffer *binder_alloc_new_buf(struct binder_alloc *alloc,
					   size_t data_size,
					   size_t offsets_size,
					   size_t extra_buffers_size,
					   int is_async)
{
	struct binder_buffer *buffer;
	mutex_lock(&alloc->mutex);
	buffer = binder_alloc_new_buf_locked(alloc, data_size, offsets_size,
					     extra_buffers_size, is_async);
	mutex_unlock(&alloc->mutex);
	return buffer;
}

struct binder_buffer *binder_alloc_new_buf_locked(struct binder_alloc *alloc,
						  size_t data_size,
						  size_t offsets_size,
						  size_t extra_buffers_size,
						  int is_async)
{
	struct rb_node *n = alloc->free_buffers.rb_node;
	struct binder_buffer *buffer;
	size_t buffer_size;
	struct rb_node *best_fit = NULL;
	void *has_page_addr;
	void *end_page_addr;
	size_t size, data_offsets_size;
	int ret;
	if (alloc->vma == NULL) {
		//vma为空
		return ERR_PTR(-ESRCH);
	}
    //data_offsets_size为对齐的data_size+对齐的offsets_size
	data_offsets_size = ALIGN(data_size, sizeof(void *)) +
		ALIGN(offsets_size, sizeof(void *));

	if (data_offsets_size < data_size || data_offsets_size < offsets_size) {
	    //data_offsets_size不符合条件，返回	
		return ERR_PTR(-EINVAL);
	}
	//调用binder_transaction时，extra_buffers_size为0
	size = data_offsets_size + ALIGN(extra_buffers_size, sizeof(void *));
	if (size < data_offsets_size || size < extra_buffers_size) {
		//检查extra_buffer_size
		return ERR_PTR(-EINVAL);
	}
	if (is_async &&
	    alloc->free_async_space < size + sizeof(struct binder_buffer)) {
	    //异步空间不满足条件返回错误	
		return ERR_PTR(-ENOSPC);
	}

	size = max(size, sizeof(void *));
    //遍历红黑树free_buffers，找到空闲红黑树的符合的空闲buffer
	while (n) {
		buffer = rb_entry(n, struct binder_buffer, rb_node);
		buffer_size = binder_alloc_buffer_size(alloc, buffer);

		if (size < buffer_size) {
			best_fit = n;
			n = n->rb_left;
		} else if (size > buffer_size)
			n = n->rb_right;
		else {
			best_fit = n;
			break;
		}
	}
	//当没有找到完全相等的空闲buffer时
	if (best_fit == NULL) {
		size_t allocated_buffers = 0;
		size_t largest_alloc_size = 0;
		size_t total_alloc_size = 0;
		size_t free_buffers = 0;
		size_t largest_free_size = 0;
		size_t total_free_size = 0;
        //遍历已分配的红黑树allocated_buffers节点,计算总的buffers值total_alloc_size
        //并获取最大的buffer大小largest_alloc_size
		for (n = rb_first(&alloc->allocated_buffers); n != NULL;
		     n = rb_next(n)) {
			buffer = rb_entry(n, struct binder_buffer, rb_node);
			buffer_size = binder_alloc_buffer_size(alloc, buffer);
			allocated_buffers++;
			total_alloc_size += buffer_size;
			if (buffer_size > largest_alloc_size)
				largest_alloc_size = buffer_size;
		}
		//遍历已分配的红黑树free_buffers节点,计算总的buffers值total_free_size
        //并获取最大的buffer大小largest_free_size
		for (n = rb_first(&alloc->free_buffers); n != NULL;
		     n = rb_next(n)) {
			buffer = rb_entry(n, struct binder_buffer, rb_node);
			buffer_size = binder_alloc_buffer_size(alloc, buffer);
			free_buffers++;
			total_free_size += buffer_size;
			if (buffer_size > largest_free_size)
				largest_free_size = buffer_size;
		}
	    //没有空间，返回错误	
		return ERR_PTR(-ENOSPC);
	}
	if (n == NULL) {
		buffer = rb_entry(best_fit, struct binder_buffer, rb_node);
		buffer_size = binder_alloc_buffer_size(alloc, buffer);
	}
	
	has_page_addr =
		(void *)(((uintptr_t)buffer->data + buffer_size) & PAGE_MASK);
	end_page_addr =
		(void *)PAGE_ALIGN((uintptr_t)buffer->data + size);
	if (end_page_addr > has_page_addr)
		end_page_addr = has_page_addr;
	//为指定的虚拟空间分配物理页面,end_page_addr为用户空间地址
	ret = binder_update_page_range(alloc, 1,
	    (void *)PAGE_ALIGN((uintptr_t)buffer->data), end_page_addr);
	if (ret)
		return ERR_PTR(ret);

	if (buffer_size != size) {
	    //新分配一个buffer并加入到红黑树中
		struct binder_buffer *new_buffer;
		new_buffer = kzalloc(sizeof(*buffer), GFP_KERNEL);
		if (!new_buffer) {
			goto err_alloc_buf_struct_failed;
		}
		new_buffer->data = (u8 *)buffer->data + size;
		list_add(&new_buffer->entry, &buffer->entry);
		new_buffer->free = 1;
		binder_insert_free_buffer(alloc, new_buffer);
	}
    //将best_fit从free_buffers红黑树中释放出来
	rb_erase(best_fit, &alloc->free_buffers);
	buffer->free = 0;
	buffer->free_in_progress = 0;
	//将buffer插入到已分配红黑树中
	binder_insert_allocated_buffer_locked(alloc, buffer);
	buffer->data_size = data_size;
	buffer->offsets_size = offsets_size;
	buffer->async_transaction = is_async;
	buffer->extra_buffers_size = extra_buffers_size;
	if (is_async) {
		alloc->free_async_space -= size + sizeof(struct binder_buffer);
	}
	return buffer;

err_alloc_buf_struct_failed:
	//释放物理内存
	binder_update_page_range(alloc, 0,
				 (void *)PAGE_ALIGN((uintptr_t)buffer->data),
				 end_page_addr);
	return ERR_PTR(-ENOMEM);
}

static int binder_update_page_range(struct binder_alloc *alloc, int allocate,
				    void *start, void *end)
{
	void *page_addr;
	unsigned long user_page_addr;
	struct binder_lru_page *page;
	struct vm_area_struct *vma = NULL;
	struct mm_struct *mm = NULL;
	bool need_mm = false;

	if (end <= start)
		return 0;

	if (allocate == 0)
		goto free_range;
    //遍历物理页面,检查物理地址是否为非空
	for (page_addr = start; page_addr < end; page_addr += PAGE_SIZE) {
		page = &alloc->pages[(page_addr - alloc->buffer) / PAGE_SIZE];
		if (!page->page_ptr) {
			need_mm = true;
			break;
		}
	}

	if (need_mm && mmget_not_zero(alloc->vma_vm_mm))
		mm = alloc->vma_vm_mm;

	if (mm) {
		down_write(&mm->mmap_sem);
		vma = alloc->vma;
	}

	if (!vma && need_mm) {
		//映射用户空间到物理页面失败,vma为空
		goto err_no_vma;
	}

	for (page_addr = start; page_addr < end; page_addr += PAGE_SIZE) {
		int ret;
		bool on_lru;
		size_t index;

		index = (page_addr - alloc->buffer) / PAGE_SIZE;
		page = &alloc->pages[index];

		if (page->page_ptr) {
			on_lru = list_lru_del(&binder_alloc_lru, &page->lru);
			continue;
		}
	    //以页为单位，为内核地址分配物理地址	
		page->page_ptr = alloc_page(GFP_KERNEL |
					    __GFP_HIGHMEM |
					    __GFP_ZERO);
		if (!page->page_ptr) {
			goto err_alloc_page_failed;
		}
		page->alloc = alloc;
		INIT_LIST_HEAD(&page->lru);
        //映射内核地址到物理页面
		ret = map_kernel_range_noflush((unsigned long)page_addr,
					       PAGE_SIZE, PAGE_KERNEL,
					       &page->page_ptr);
		flush_cache_vmap((unsigned long)page_addr,
				(unsigned long)page_addr + PAGE_SIZE);
		if (ret != 1) {
			goto err_map_kernel_failed;
		}
		//映射用户地址
		user_page_addr =
			(uintptr_t)page_addr + alloc->user_buffer_offset;
		ret = vm_insert_page(vma, user_page_addr, page[0].page_ptr);
		if (ret) {
			goto err_vm_insert_page_failed;
		}

		if (index + 1 > alloc->pages_high)
			alloc->pages_high = index + 1;
	}
	if (mm) {
		up_write(&mm->mmap_sem);
		mmput(mm);
	}
	return 0;

free_range:
	for (page_addr = end - PAGE_SIZE; page_addr >= start;
	     page_addr -= PAGE_SIZE) {
		bool ret;
		size_t index;

		index = (page_addr - alloc->buffer) / PAGE_SIZE;
		page = &alloc->pages[index];
		ret = list_lru_add(&binder_alloc_lru, &page->lru);
		continue;

err_vm_insert_page_failed:
		unmap_kernel_range((unsigned long)page_addr, PAGE_SIZE);
err_map_kernel_failed:
		__free_page(page->page_ptr);
		page->page_ptr = NULL;
err_alloc_page_failed:
err_page_ptr_cleared:
		;
	}
err_no_vma:
	if (mm) {
		up_write(&mm->mmap_sem);
		mmput(mm);
	}
	return vma ? -ENOMEM : -ESRCH;
}
```

至此，Binder设备的内存映射就建立了，其形式如下:

![](/img/bill/in-posts/2019-07-02/buffer_model.png)

## 2.4 `binder_ioctl`

上层与binder通信时，在进入到驱动前，会调用到IPCThreadState去执行。在talkWithDriver方法中，有这样的逻辑:

```c++
//frameworks/native/libs/binder/IPCThreadState.cpp
//bwr为binder_write_read，上层是通过bwr去交换数据的,协议是BINDER_WRITE_READ
if (ioctl(mProcess->mDriverFD, BINDER_WRITE_READ, &bwr) >= 0)
    err = NO_ERROR;
```

对接到底层的驱动，需要看`binder_ioctl`的实现，针对`BINDER_WRITE_READ`详细看其实现:

```c
//linux-4.9/drivers/android/binder.c
static long binder_ioctl(struct file *filp, unsigned int cmd, unsigned long arg)
{
	int ret;
    //还是通过private_data获取binder进程
	struct binder_proc *proc = filp->private_data;
	struct binder_thread *thread;
	unsigned int size = _IOC_SIZE(cmd);
	void __user *ubuf = (void __user *)arg;
	binder_selftest_alloc(&proc->alloc);
    ...	
    //获取binder线程,binder_proc会维护一个threads的红黑树，
    //这里是找出与进程相同pid号的线程
	thread = binder_get_thread(proc);
	if (thread == NULL) {
		ret = -ENOMEM;
		goto err;
	}
	switch (cmd) {
	case BINDER_WRITE_READ:
	    //调用binder_ioctl_write_read处理
		ret = binder_ioctl_write_read(filp, cmd, arg, thread);
		if (ret)
			goto err;
		break;
    ...	
	default:
		ret = -EINVAL;
		goto err;
	}
	ret = 0;
err:
	if (thread)
		thread->looper_need_return = false;
    ...
err_unlocked:
	return ret;
}

static int binder_ioctl_write_read(struct file *filp,
				unsigned int cmd, unsigned long arg,
				struct binder_thread *thread)
{
	int ret = 0;
	struct binder_proc *proc = filp->private_data;
	unsigned int size = _IOC_SIZE(cmd);
	void __user *ubuf = (void __user *)arg;
	struct binder_write_read bwr;

	if (size != sizeof(struct binder_write_read)) {
		ret = -EINVAL;
		goto out;
	}
	//从用户空间获取binder_write_read类型的bwr
	if (copy_from_user(&bwr, ubuf, sizeof(bwr))) {
		ret = -EFAULT;
		goto out;
	}
    //write_size大于0，说明有内容写入内核驱动中。	
	if (bwr.write_size > 0) {
		ret = binder_thread_write(proc, thread,
					  bwr.write_buffer,
					  bwr.write_size,
					  &bwr.write_consumed);
		if (ret < 0) {
			bwr.read_consumed = 0;
			if (copy_to_user(ubuf, &bwr, sizeof(bwr)))
				ret = -EFAULT;
			goto out;
		}
	}
    //read_size大于0，说明有内容需要从内核驱动中读取。	
	if (bwr.read_size > 0) {
		ret = binder_thread_read(proc, thread, bwr.read_buffer,
					 bwr.read_size,
					 &bwr.read_consumed,
					 filp->f_flags & O_NONBLOCK);
		binder_inner_proc_lock(proc);
		//当proc的todo链表非空时，调用binder_wakeup_proc_ilocked唤醒线程
		if (!binder_worklist_empty_ilocked(&proc->todo))
			binder_wakeup_proc_ilocked(proc);
		binder_inner_proc_unlock(proc);
		if (ret < 0) {
			if (copy_to_user(ubuf, &bwr, sizeof(bwr)))
				ret = -EFAULT;
			goto out;
		}
	}
    //返回信息到用户空间	
	if (copy_to_user(ubuf, &bwr, sizeof(bwr))) {
		ret = -EFAULT;
		goto out;
	}
out:
	return ret;
}
```

`binder_ioctl_write_read`通过`copy_from_user`获取上层的结构体数据`binder_write_read`,回过头来看talkWithDriver的实现如下:

```c++
//frameworks/native/libs/binder/IPCThreadState.cpp
//talkWithDriver前，首先需要将想要发送给驱动的内容mOut填充好。
status_t IPCThreadState::talkWithDriver(bool doReceive)
{
    if (mProcess->mDriverFD <= 0) {
        return -EBADF;
    }
    binder_write_read bwr;
    //当前数据位置大于当前数据大小时，表明需要读取
    const bool needRead = mIn.dataPosition() >= mIn.dataSize();
    //只要还在读过程中就不会去做写操作
    const size_t outAvail = (!doReceive || needRead) ? mOut.dataSize() : 0;
    //写缓冲区大小
    bwr.write_size = outAvail;
    //write_buffer指向了用户空间缓冲区地址(mOut)
    //以joinThreadPool为例，调用了mOut.writeInt32(BC_ENTER_LOOPER)
    //write_buffer即指向协议BC_ENTER_LOOPER
    bwr.write_buffer = (uintptr_t)mOut.data();

    //将要读取的内容信息
    if (doReceive && needRead) {
        //read_size是读缓冲区大小,大小为mIn的容量
        bwr.read_size = mIn.dataCapacity();
        //read_buffer指向了用户缓冲区地址(mIn)
        bwr.read_buffer = (uintptr_t)mIn.data();
    } else {
        //假如不需要读取，都设置为0
        bwr.read_size = 0;
        bwr.read_buffer = 0;
    }
    ... 
    //假如读写都为0，马上返回
    if ((bwr.write_size == 0) && (bwr.read_size == 0)) return NO_ERROR;

    bwr.write_consumed = 0;
    bwr.read_consumed = 0;
    status_t err;
    do {
        //这里对接到上文提到的驱动binder_ioctl,返回后，bwr内容被更新
        if (ioctl(mProcess->mDriverFD, BINDER_WRITE_READ, &bwr) >= 0)
            err = NO_ERROR;
        else
            err = -errno;
        if (mProcess->mDriverFD <= 0) {
            err = -EBADF;
        }
    } while (err == -EINTR);

    if (err >= NO_ERROR) {
        if (bwr.write_consumed > 0) {
            if (bwr.write_consumed < mOut.dataSize())
                mOut.remove(0, bwr.write_consumed);
            else {
                mOut.setDataSize(0);
                processPostWriteDerefs();
            }
        }
        if (bwr.read_consumed > 0) {
            mIn.setDataSize(bwr.read_consumed);
            mIn.setDataPosition(0);
        }
        IF_LOG_COMMANDS() {
            TextOutput::Bundle _b(alog);
            alog << "Remaining data size: " << mOut.dataSize() << endl;
            alog << "Received commands from driver: " << indent;
            const void* cmds = mIn.data();
            const void* end = mIn.data() + mIn.dataSize();
            alog << HexDump(cmds, mIn.dataSize()) << endl;
            //解析驱动传上来的信息
            while (cmds < end) cmds = printReturnCommand(alog, cmds);
            alog << dedent;
        }
        return NO_ERROR;
    }
    return err;
}
```

talkWithDriver即操作`binder_write_read`结构体，将需要传递给驱动的协议以及内容通过write系列接口写入到Parcel类型的mOut中，并通过`binder_ioctl`给到驱动，驱动经过处理完之后，还是通过`binder_write_read`结构体中获取驱动返回的协议以及内容，并在waitForResponse内进行解析:

```c++
//frameworks/native/libs/binder/IPCThreadState.cpp
status_t IPCThreadState::waitForResponse(Parcel *reply, status_t *acquireResult)
{
    uint32_t cmd;
    int32_t err;

    while (1) {
        //调用完talkWithDriver后，mIn中刷新了从驱动上来的数据
        if ((err=talkWithDriver()) < NO_ERROR) break;
        err = mIn.errorCheck();
        if (err < NO_ERROR) break;
        if (mIn.dataAvail() == 0) continue;

        cmd = (uint32_t)mIn.readInt32();
        ...
        switch (cmd) {
            ...//解析驱动上来的BR_xxxx协议
        }
}
```

至此，分析了从IPCThreadState到驱动，再读取驱动上来的信息，再进行解析的流程.

## 2.5 `service_manager`的注册过程

为了了解binder代理端和服务端的交互，需要理解`service_manager`在其中的角色。由于涉及到部分未经分析的方法，先将`service_manager`的流程进行简单化:

```c++
//frameworks/native/cmds/servicemanager/service_manager.c
int main(int argc, char** argv)
{
    char *driver;
    if (argc > 1) {
        driver = argv[1];
    } else {
        driver = "/dev/binder";
    }
    //1.打开binder驱动,且映射大小为124K
    bs = binder_open(driver, 128*1024);
    ...
    //2.将自身注册为context manager的角色
    if (binder_become_context_manager(bs)) {
        return -1;
    }
    ...
    //3.循环处理消息
    binder_loop(bs, svcmgr_handler);
}
```

1.`binder_open`与驱动的`binder_open`不一样,其逻辑如下:

```c++
//frameworks/native/cmds/servicemanager/binder.c
struct binder_state *binder_open(const char* driver, size_t mapsize)
{
    struct binder_state *bs;
    struct binder_version vers;
    bs = malloc(sizeof(*bs));
    //检查bs是否分配成功
    ...
    //对接到驱动的binder_open,底层创建了一个binder_proc结构体
    bs->fd = open(driver, O_RDWR | O_CLOEXEC);
    //检查fd是否创建成功
    ...
    //获取当前BINDER_VERSION版本
    if ((ioctl(bs->fd, BINDER_VERSION, &vers) == -1) ||
        (vers.protocol_version != BINDER_CURRENT_PROTOCOL_VERSION)) {
        ... 
        goto fail_open;
    }

    bs->mapsize = mapsize;
    //底层调用binder_mmap并将返回地址存到bs的mapped字段中,详情参见binder_mmap
    bs->mapped = mmap(NULL, mapsize, PROT_READ, MAP_PRIVATE, bs->fd, 0);
    if (bs->mapped == MAP_FAILED) {
        ...
        goto fail_map;
    }
    return bs;
fail_map:
    close(bs->fd);
fail_open:
    free(bs);
    return NULL;
} 
```

2.`binder_become_context_manager`注册为ServiceManager

```c++
//frameworks/native/cmds/servicemanager/binder.c
int binder_become_context_manager(struct binder_state *bs)
{
    return ioctl(bs->fd, BINDER_SET_CONTEXT_MGR, 0);
}
```

在驱动中最终会调用到`binder_ioctl_set_ctx_mgr`

```c++
//frameworks/native/cmds/servicemanager/binder.c
static int binder_ioctl_set_ctx_mgr(struct file *filp)
{
	int ret = 0;
	struct binder_proc *proc = filp->private_data;
	struct binder_context *context = proc->context;
	struct binder_node *new_node;
	kuid_t curr_euid = current_euid();

	mutex_lock(&context->context_mgr_node_lock);
	//已经存在了ServiceManager,返回EBUSY
	if (context->binder_context_mgr_node) {
		pr_err("BINDER_SET_CONTEXT_MGR already set\n");
		ret = -EBUSY;
		goto out;
	}
    ...	
	//设置uid
	if (uid_valid(context->binder_context_mgr_uid)) {
		if (!uid_eq(context->binder_context_mgr_uid, curr_euid)) {
		    ....	
			ret = -EPERM;
			goto out;
		}
	} else {
		context->binder_context_mgr_uid = curr_euid;
	}
	//为serviceManager新建binder_node,serviceManager只有唯一一个binder_node
	new_node = binder_new_node(proc, NULL);
	if (!new_node) {
		ret = -ENOMEM;
		goto out;
	}
	binder_node_lock(new_node);
	new_node->local_weak_refs++;
	new_node->local_strong_refs++;
	new_node->has_strong_ref = 1;
	new_node->has_weak_ref = 1;
	//binder_context_mgr_node指向new_node
	context->binder_context_mgr_node = new_node;
	binder_node_unlock(new_node);
	binder_put_node(new_node);
out:
	mutex_unlock(&context->context_mgr_node_lock);
	return ret;
}
```

3.`binder_loop(bs, svcmgr_handler)`

```c
//frameworks/native/cmds/servicemanager/binder.c
void binder_loop(struct binder_state *bs, binder_handler func)
{
    int res;
    struct binder_write_read bwr;
    uint32_t readbuf[32];
    //write方面的属性设置为0,即表明不传递数据到驱动,只接收驱动上来的信息.
    bwr.write_size = 0;
    bwr.write_consumed = 0;
    bwr.write_buffer = 0;
    //这里将BC_ENTER_LOOPER送到驱动
    readbuf[0] = BC_ENTER_LOOPER;
    binder_write(bs, readbuf, sizeof(uint32_t));

    for (;;) {
        bwr.read_size = sizeof(readbuf);
        bwr.read_consumed = 0;
        bwr.read_buffer = (uintptr_t) readbuf;
        //进程阻塞在获取驱动的信息中,一旦唤醒,就读取bwr信息,并进程处理.
        res = ioctl(bs->fd, BINDER_WRITE_READ, &bwr);
        //错误处理 
        ... 
        //调用binder_parse解析驱动上来的信息，并将回调函数传入，在特定的条件下调用回调函数 
        res = binder_parse(bs, 0, (uintptr_t) readbuf, bwr.read_consumed, func);
        //错误处理 
        ... 
    }
}
```

```c
//frameworks/native/cmds/servicemanager/binder.c
int binder_parse(struct binder_state *bs, struct binder_io *bio,
                 uintptr_t ptr, size_t size, binder_handler func)
{
    int r = 1;
    uintptr_t end = ptr + (uintptr_t) size;

    while (ptr < end) {
        uint32_t cmd = *(uint32_t *) ptr;
        ptr += sizeof(uint32_t);
    switch(cmd) {
    case BR_NOOP:
            break;
        case BR_TRANSACTION_COMPLETE:
            break;
        case BR_INCREFS:
        case BR_ACQUIRE:
        case BR_RELEASE:
        case BR_DECREFS:
            ptr += sizeof(struct binder_ptr_cookie);
            break;
        case BR_TRANSACTION: {
            struct binder_transaction_data *txn = (struct binder_transaction_data *) ptr;
            if ((end - ptr) < sizeof(*txn)) {
                ...
                return -1;
            }
            if (func) {
                unsigned rdata[256/4];
                struct binder_io msg;
                struct binder_io reply;
                int res;

                bio_init(&reply, rdata, sizeof(rdata), 4);
                bio_init_from_txn(&msg, txn);
                //调用func处理函数
                res = func(bs, txn, &msg, &reply);
                if (txn->flags & TF_ONE_WAY) {
                    binder_free_buffer(bs, txn->data.ptr.buffer);
                } else {
                    binder_send_reply(bs, &reply, txn->data.ptr.buffer, res);
                }
            }
            ptr += sizeof(*txn);
            break;
        }
        case BR_REPLY: {
            struct binder_transaction_data *txn = (struct binder_transaction_data *) ptr;
            if ((end - ptr) < sizeof(*txn)) {
                ...
                return -1;
            }
            if (bio) {
                bio_init_from_txn(bio, txn);
                bio = 0;
            } else {
                /* todo FREE BUFFER */
            }
            ptr += sizeof(*txn);
            r = 0;
            break;
        } 
        ....
    }
    return r;
}
```

小结一下，关于serviceManager会打开binder设备节点，然后进行内存映射，紧接着创建了一个特殊的`binder_node`,通过上下文context的`binder_context_mgr_node`可以找到该node。下一步将`BC_ENTER_LOOPER`通过ioctl传递到驱动层，告诉该进程已经准备好了，底层将会把对应的线程状态更新。最后serviceManager传入`binder_write_read`结构体,并将write方面的设置为空,read方面的设置为sizeof(readbuf)表明ServiceMangaer只接收驱动上来的信息,并进入休眠,等待消息唤醒进程.   一旦有被唤醒,说明有消息传上来，那么就读取数据再进行处理,特定的协议还会调用回调函数处理。

## 2.6 binder服务的注册过程

Service通过addService生成`binder_node`,并生成`binder_ref`插入到serviceManager中的红黑树中．当Client通过getService获取服务时，serviceManager通过名字，找到对应的handle值后，也会在目标进程client中插入`binder_ref`,这就是client能够获取到在自身的进程获取到`binder_ref`的原因．下图解释了该流程.

![](/img/bill/in-posts/2019-07-02/ref_and_node.png)

既然现在serviceManager已经准备就绪，服务就可以通过serviceManager进行注册，一般proxy可以通过serviceManager能够查询到关键的任务。那么服务究竟在驱动这一层究竟做了什么操作呢?

以服务的注册为例，首先需要调用IServiceManager的addService来将服务注册。

```c++
sm->addService(String16(SERVICE::getServiceName()), new SERVICE(), 
        allowIsolated, dumpFlags);
```

```c++
//frameworks/native/libs/binder/IServiceManager.cpp
virtual status_t addService(const String16& name, const sp<IBinder>& service,
                            bool allowIsolated, int dumpsysPriority) {
    Parcel data, reply;
    data.writeInterfaceToken(IServiceManager::getInterfaceDescriptor());
    data.writeString16(name);
    //将服务写入到data并传给Binder驱动!
    data.writeStrongBinder(service);
    data.writeInt32(allowIsolated ? 1 : 0);
    data.writeInt32(dumpsysPriority);
    //remote返回的是mRemote,即IBinder
    status_t err = remote()->transact(ADD_SERVICE_TRANSACTION, data, &reply);
    return err == NO_ERROR ? reply.readExceptionCode() : err;
}

//frameworks/native/libs/binder/BpBinder.cpp
BpBinder继承了IBinder,调用的transact遵循多态
status_t BpBinder::transact(
    uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags)
{
    if (mAlive) {
        //命令协议为BC_TRANSACTION
        status_t status = IPCThreadState::self()->transact(
            mHandle, code, data, reply, flags);
        if (status == DEAD_OBJECT) mAlive = 0;
        return status;
    }
    return DEAD_OBJECT;
}
```

至此，进入IPCThreadState的transact方法,具体方法在后文会分析，在这里我们可以认为将code(ADD_SERVICE_TRANSACTION)以及Parcel数据转化为`binder_transaction_data`这个数据结构，并在后续调用talkWithDriver中，使用数据结构`binder_write_read`进行装载,最后通过ioctl传递到驱动。

至于驱动是如何处理从Service传下来的数据，后续将会详细分析，直接跳转到`service_manager`是如何接收并处理驱动的信息的:

```c++
//frameworks/native/cmds/servicemanager/service_manager.c
int svcmgr_handler(struct binder_state *bs,
                   struct binder_transaction_data *txn,
                   struct binder_io *msg,
                   struct binder_io *reply)
{
...
    //对应ADD_SERVICE_TRANSACTION
    case SVC_MGR_ADD_SERVICE:
        s = bio_get_string16(msg, &len);
        if (s == NULL) {
            return -1;
        }
        //bio_get_ref首先将binder_io类型的msg抽取出flat_binder_object数据
        //并从flat_binder_object中获取出handle
        handle = bio_get_ref(msg);
        allow_isolated = bio_get_uint32(msg) ? 1 : 0;
        dumpsys_priority = bio_get_uint32(msg);
        //调用do_add_service
        if (do_add_service(bs, s, len, handle, txn->sender_euid, allow_isolated, 
            dumpsys_priority,txn->sender_pid))
            return -1;
        break;
...
}

uint32_t bio_get_ref(struct binder_io *bio)
{
    struct flat_binder_object *obj;
    //这里获取了服务的内容,估计是经过了一次拷贝后,将服务的信息拷贝到了ServiceManager的内核空间中,又由于内核空间和用户空间经过了映射,所以ServiceManager可以直接获取数据. 
    obj = _bio_get_obj(bio);
    if (!obj)
        return 0;
    //服务首先写入时,类型为BINDER_TYPE_BINDER,但在驱动的bidner_transaction中的
    //binder_translate_binder方法中会改为BINDER_TYPE_HANDLE,并尝试找到binder_node对应的binder_ref,最后将binder_ref的handle值更新下去.所以serviceManager拿到的已经不是binder_node的信息,而是binder_ref的handle值.
    if (obj->hdr.type == BINDER_TYPE_HANDLE)
        return obj->handle;
    return 0;
}

int do_add_service(struct binder_state *bs, const uint16_t *s, size_t len, uint32_t handle,
                   uid_t uid, int allow_isolated, uint32_t dumpsys_priority, pid_t spid) {
    struct svcinfo *si;
    if (!handle || (len == 0) || (len > 127))
        return -1;

    if (!svc_can_register(s, len, spid, uid)) {
        ...
        return -1;
    }
    //根据服务名s,从svclist链表中找是否存在相同的服务
    si = find_svc(s, len);
    if (si) {//存在相同的service,则更新handle值
        if (si->handle) {
            ....
            svcinfo_death(bs, si);
        }
        si->handle = handle;
    } else {
        si = malloc(sizeof(*si) + (len + 1) * sizeof(uint16_t));
        //处理分配错误逻辑，并返回 
        ...
        si->handle = handle;
        si->len = len;
        memcpy(si->name, s, (len + 1) * sizeof(uint16_t));
        si->name[len] = '\0';
        si->death.func = (void*) svcinfo_death;
        si->death.ptr = si;
        si->allow_isolated = allow_isolated;
        si->dumpsys_priority = dumpsys_priority;
        //将服务名安排至头部
        si->next = svclist;
        svclist = si;
    }
    //增加指定handle的binder_ref对应的binder_node的强引用计数
    binder_acquire(bs, handle);
    binder_link_to_death(bs, handle, &si->death);
    return 0;
}
```

由此可见，对于所有的Binder服务注册，驱动并不参与管理服务列表,驱动只是进行binder对象的传输，在传输过程中,服务对象(`binder_node`)会经过转换为对应的(`binder_ref`).那么当ServiceManager获取上来的则是对应服务的handle值,并将该值保存到链表中进行管理。

至此还有一个疑问,serviceManager是如何通过`bio_get_ref`获取到服务的handle值,并将之加入到链表中管理的呢?

当服务将binder服务写入到驱动后,驱动处理完毕后会发送`BR_TRANSACtiON`到ServiceManager中,ServiceManager收到后会走如下逻辑:

```c
//frameworks/native/cmds/servicemanager/binder.c
int binder_parse(struct binder_state *bs, struct binder_io *bio,
                 uintptr_t ptr, size_t size, binder_handler func)
...
case BR_TRANSACTION: {
    //当ServiceManager的等待线程被唤醒后,读取的内容即ptr指向的内容,即binder_transaction_data
    //此时已经完成了一次拷贝过程,即从服务进程拷贝到ServiceManager的用户空间的缓冲区中
    struct binder_transaction_data *txn = (struct binder_transaction_data *) ptr;
    if ((end - ptr) < sizeof(*txn)) {
        ALOGE("parse: txn too small!\n");
        return -1;
    }
    if (func) {
        unsigned rdata[256/4];
        struct binder_io msg;
        struct binder_io reply;
        int res;

        bio_init(&reply, rdata, sizeof(rdata), 4);
        //将binder_transaction_data的内容放到bio_io数据结构中
        bio_init_from_txn(&msg, txn);
        //传入bio_io结构体,调用func回调函数
        res = func(bs, txn, &msg, &reply);
        if (txn->flags & TF_ONE_WAY) {
            binder_free_buffer(bs, txn->data.ptr.buffer);
        } else {
            binder_send_reply(bs, &reply, txn->data.ptr.buffer, res);
        }
    }
    ptr += sizeof(*txn);
    break;
}
...
}
```

```
//frameworks/native/cmds/servicemanager/binder.c
void bio_init_from_txn(struct binder_io *bio, struct binder_transaction_data *txn)
{
    //bio的data,data0均指向数据缓冲区起始地址
    bio->data = bio->data0 = (char *)(intptr_t)txn->data.ptr.buffer;
    //bio的offs,offs0均指向偏移量,可用于获取数据缓冲区的Binder对象
    bio->offs = bio->offs0 = (binder_size_t *)(intptr_t)txn->data.ptr.offsets;
    //bio的data_avail即为基础数据缓冲区大小
    bio->data_avail = txn->data_size;
    //bio的offs_avail即为以flat_binder_object的数量
    bio->offs_avail = txn->offsets_size / sizeof(size_t);
    bio->flags = BIO_F_SHARED;
}

static struct flat_binder_object *_bio_get_obj(struct binder_io *bio)
{
    size_t n;
    size_t off = bio->data - bio->data0;
    //遍历offs_avail,即flat_binder_object的数量,调用bio_get获取下一个
    //flat_binder_object对象
    for (n = 0; n < bio->offs_avail; n++) {
        if (bio->offs[n] == off)
            return bio_get(bio, sizeof(struct flat_binder_object));
    }

    bio->data_avail = 0;
    bio->flags |= BIO_F_OVERFLOW;
    return NULL;
}

static void *bio_get(struct binder_io *bio, size_t size)
{
    size = (size + 3) & (~3);

    if (bio->data_avail < size){
        bio->data_avail = 0;
        bio->flags |= BIO_F_OVERFLOW;
        return NULL;
    }  else {
        void *ptr = bio->data;
        bio->data += size;
        bio->data_avail -= size;
        return ptr;
    }
}
```

最后展示数据缓冲区的结构理解读取`flat_binder_object`的原理.

![](/img/bill/in-posts/2019-07-02/flat_binder_object.png)

## 2.7 binder代理端通信流程

既然当前serviceManager已经获取到了服务的信息了，那么客户端需要使用服务时，就可以开始申请服务了。主要的流程如下所示:

1. 首先Sever发送`BC_ENTER_LOOPER`将自身注册到Binder驱动中。
2. Client通过发送`BC_TRANSACTION`要求使用服务。
3. Binder驱动收到请求后，返回`BC_TRANSACTION_COMPLETE`表示完成。
4. Binder驱动发送`BR_TRANSACTION`到Server,表明有客户需要使用服务，Server收到后返回`BC_REPLY`。为了让Binder驱动和Server双方都知道建立连接，需要从Binder驱动再发送一个`BR_TRANSACTION_COMPLETE`。最后，返回`BR_REPLY`到Client告诉它已经完成。

![](/img/bill/in-posts/2019-07-02/sequences.png)

### 2.7.1 `BC_ENTER_LOOPER`

如2.6小节所述，当服务启动完成后，一般都会调用joinThreadPool将主线程用于与Binder驱动的交互。其中jointThreadPool会调用getAndExecuteCommand接口，这里面最终会调用到ioctl，向binder设备驱动发送命令。

```c++
//frameworks/native/libs/binder/IPCThreadState.cpp
//isMain参数默认为true
void IPCThreadState::joinThreadPool(bool isMain)
{
    //上层将BC_ENTER_LOOPER写入到Parcel类型的mOut中。
    mOut.writeInt32(isMain ? BC_ENTER_LOOPER : BC_REGISTER_LOOPER);
    status_t result;
    do {
        processPendingDerefs();
        //发送并处理驱动的消息
        result = getAndExecuteCommand();
        //处理result的错误或者超时信息
        .. 
    } while (result != -ECONNREFUSED && result != -EBADF);
    //最后发送BC_EXIT_LOOPER告诉驱动该进程退出
    mOut.writeInt32(BC_EXIT_LOOPER);
    talkWithDriver(false);
}
```

getAndExecuteCommand中会调用到talkWithDriver方法，其中有`binder_ioctl`直接对接到驱动，2.4小节已经简单讲述了如何调用到`binder_thread_write`,接下来直接跳过中间步骤分析该方法:

```c++
//linux-4.9/drivers/android/binder.c
static int binder_thread_write(struct binder_proc *proc,
			struct binder_thread *thread,
			binder_uintptr_t binder_buffer, size_t size,
			binder_size_t *consumed)
{
	uint32_t cmd;
	//binder_context主要用于记录当前的systemServer对应的binder_node节点
	struct binder_context *context = proc->context;
	//buffer指向binder_buffer的起始地址
	void __user *buffer = (void __user *)(uintptr_t)binder_buffer;
	//consumed表明驱动处理了多少写数据，ptr指向该位置,即指向上层写协议数据(BC_ENTER_LOOPER)的起始位置。
	void __user *ptr = buffer + *consumed;
	void __user *end = buffer + size;

	while (ptr < end && thread->return_error.cmd == BR_OK) {
		int ret;
        //获取cmd,即BC_ENTER_LOOPER
		if (get_user(cmd, (uint32_t __user *)ptr))
			return -EFAULT;
		ptr += sizeof(uint32_t);
		if (_IOC_NR(cmd) < ARRAY_SIZE(binder_stats.bc)) {
			atomic_inc(&binder_stats.bc[_IOC_NR(cmd)]);
			atomic_inc(&proc->stats.bc[_IOC_NR(cmd)]);
			atomic_inc(&thread->stats.bc[_IOC_NR(cmd)]);
		}
		switch (cmd) {
		...
		//驱动请求进程注册一个新线程注册到线程池中处理Binder通信。
		case BC_REGISTER_LOOPER:
			binder_inner_proc_lock(proc);
			//假如已经是Binder主线程了，就不需要再通过驱动创建了
			if (thread->looper & BINDER_LOOPER_STATE_ENTERED) {
				thread->looper |= BINDER_LOOPER_STATE_INVALID;
			    ...//打印错误提示	
			} else if (proc->requested_threads == 0) {
				thread->looper |= BINDER_LOOPER_STATE_INVALID;
			    ...//打印错误提示	
			} else {
				proc->requested_threads--;
				proc->requested_threads_started++;
			}
			//设置binder线程状态为BINDER_LOOPER_STATE_REGISTERED
			thread->looper |= BINDER_LOOPER_STATE_REGISTERED;
			binder_inner_proc_unlock(proc);
			break;
	    //上层要将一个线程注册到线程池中处理Binder通信。
	    case BC_ENTER_LOOPER:
			if (thread->looper & BINDER_LOOPER_STATE_REGISTERED) {
				thread->looper |= BINDER_LOOPER_STATE_INVALID;
			    ...//打印错误提示	
			}
			//设置binder线程状态为BINDER_LOOPER_STATE_ENTERED
			thread->looper |= BINDER_LOOPER_STATE_ENTERED;
			break;	
		}
...
}
```

`BC_REGISTER_LOOPER`与`BC_ENTER_LOOPER`都没有涉及数据传输，都只是设置了`binder_thread`的loop属性,修改了线程的状态。

```
BINDER_LOOPER_STATE_REGISTERED  = 0x01,
BINDER_LOOPER_STATE_ENTERED     = 0x02,
BINDER_LOOPER_STATE_EXITED      = 0x04,
BINDER_LOOPER_STATE_INVALID     = 0x08,
BINDER_LOOPER_STATE_WAITING     = 0x10,
BINDER_LOOPER_STATE_POLL        = 0x20,
```

### 2.7.2 `BC_TRANSACTION`

当服务注册到驱动后，对应的binder线程状态就发生了改变，此时客户就可以尝试与之进行Binder通信了。一般的获取服务流程都是如下形式:

```c++
//获取ServiceManager
sp<IServiceManager> sm = defaultServiceManager();
//获取服务端的IBinder
sp<IBinder> binder = sm->getService(String16("media.drm"));
//通过interface_cast将binder转化为Bp代理端,从而可以通过代理请求服务
sp<IMediaDrmService> service = interface_cast<IMediaDrmService>(binder);
//这里使用了Binder通信
sp<IDrm> drm = service->makeDrm();
```

当proxy代理端调用transact方法时，最终的实施者是IPCThreadState.值得注意的是,BpBinder是通过ServiceManager传到客户端的,由此可知,ServieManager是找到了相关的服务,并将包含了对应服务的Handle值的BpBinder给到了客户.

```c++
//frameworks/native/libs/binder/BpBinder.cpp
status_t BpBinder::transact(
    uint32_t code, const Parcel& data, Parcel* reply, uint32_t flags)
{
    // Once a binder has died, it will never come back to life.
    if (mAlive) {
        status_t status = IPCThreadState::self()->transact(
            mHandle, code, data, reply, flags);
        if (status == DEAD_OBJECT) mAlive = 0;
        return status;
    }
    return DEAD_OBJECT;
}
```

```c++
//frameworks/native/libs/binder/IPCThreadState.cpp
status_t IPCThreadState::transact(int32_t handle,
                                  uint32_t code, const Parcel& data,
                                  Parcel* reply, uint32_t flags)
{
    status_t err;
    //默认flags设置了TF_ACCEPT_FDS
    flags |= TF_ACCEPT_FDS;
    //将协议BC_TRANSACTION,handle值传入
    err = writeTransactionData(BC_TRANSACTION, flags, handle, code, data, NULL);
    ... 
    //同步通信
    if ((flags & TF_ONE_WAY) == 0) {
        ...
        //waitForResponse调用了talkWithDriver，将数据传输到驱动
        if (reply) {
            err = waitForResponse(reply);
        } else {
            Parcel fakeReply;
            err = waitForResponse(&fakeReply);
        }
    //异步通信
    } else {
        err = waitForResponse(NULL, NULL);
    }
    return err;
}

status_t IPCThreadState::writeTransactionData(int32_t cmd, uint32_t binderFlags,
    int32_t handle, uint32_t code, const Parcel& data, status_t* statusBuffer)
{
    //binder_transaction_data描述进程间通信过程中所传输的数据
    binder_transaction_data tr;
    //默认初始化tr
    tr.target.ptr = 0;
    //设置binder_transaction_data的target.handle值
    tr.target.handle = handle;
    tr.code = code;//即
    tr.flags = binderFlags;
    tr.cookie = 0;
    tr.sender_pid = 0;
    tr.sender_euid = 0;

    const status_t err = data.errorCheck();
    //将Parcel类型的data内容传到tr中。
    if (err == NO_ERROR) {
        //数据缓冲区大小
        tr.data_size = data.ipcDataSize();
        //buffer指向数据缓冲区首地址
        tr.data.ptr.buffer = data.ipcData();
        //offsets_size指向后面Binder对象的大小
        tr.offsets_size = data.ipcObjectsCount()*sizeof(binder_size_t);
        //offsets指向Parcel的mObjects数组，其中保存着前面flat_binder_object的地址
        tr.data.ptr.offsets = data.ipcObjects();
    }
    ... 
    //mOut写入通信协议cmd，这里指BC_TRANSACTION
    mOut.writeInt32(cmd);
    //紧接其后写入通信数据
    mOut.write(&tr, sizeof(tr));
    return NO_ERROR;
}
```

上层创建了一个`binder_transaction_data`用以描述Parcel data的内容，这是驱动用以描述进程间传输数据的数据结构。最后通过mOut写入协议以及数据后，就可以使用waitForResponse来将数据传递到驱动了。其中tr.data.ptr.buffer指向数据起始地址，tr.data.ptr.offsets指向偏移数组起始地址，可以通过该偏移数组轻松获取`flat_binder_object`对象。

由于talkWithDriver的逻辑之前已经分析过了, 现在可以直接进入驱动分析`BC_TRANSACITON`的处理了,如下是`binder_thread_write`的部分逻辑:

```c++
//linux-4.9/drivers/android/binder.c
static int binder_thread_write(struct binder_proc *proc,
			struct binder_thread *thread,
			binder_uintptr_t binder_buffer, size_t size,
			binder_size_t *consumed){
...
    case BC_TRANSACTION:
    case BC_REPLY: {
    	struct binder_transaction_data tr;
        //获取上层的通信数据binder_transaction_data
    	if (copy_from_user(&tr, ptr, sizeof(tr)))
    		return -EFAULT;
    	ptr += sizeof(tr);
    	//调用binder_transaction处理,并在输入判断是BC_TRANSACTION还是BC_REPLY
    	binder_transaction(proc, thread, &tr,
    			   cmd == BC_REPLY, 0);
    	break;
    }
}
...
```

首先分析`binder_transaction`:
```c++
//linux-4.9/drivers/android/binder.c
static void binder_transaction(struct binder_proc *proc,
			       struct binder_thread *thread,
			       struct binder_transaction_data *tr, int reply,
			       binder_size_t extra_buffers_size)
{
	int ret;
	struct binder_transaction *t;
	struct binder_work *tcomplete;
	binder_size_t *offp, *off_end, *off_start;
	binder_size_t off_min;
	u8 *sg_bufp, *sg_buf_end;
	struct binder_proc *target_proc = NULL;
	struct binder_thread *target_thread = NULL;
	struct binder_node *target_node = NULL;
	struct binder_transaction *in_reply_to = NULL;
	...
	struct binder_context *context = proc->context;
    ...
    //BC_REPLY，暂不分析
	if (reply) {
	    ....	
	} 
	//BC_TRANSACTION
	else {
		//本情况属于代理端请求服务,handle存在,该handle值是从ServiceManager中获得的
		if (tr->target.handle) {
			struct binder_ref *ref;
		    //对进程公共部分操作，需要上锁	
			binder_proc_lock(proc);
			//在binder进程(binder_proc)的红黑树refs_by_desc中搜索binder_ref,通过desc去寻找。
			//解释一下，当服务注册时，会在ServiceManager中创建与新建binder_node对应的binder_ref，
			//并加入两个红黑树当中．那么当client需要查询服务时，ServiceManager会首先查找是否存在，如果存在，
			//会在client内核空间中的红黑树中新建binder_ref,所以这里当client发起binder_transaciton时，一定要
			//在client所在的红黑树refs_by_desc中找到对应的binder_ref
			ref = binder_get_ref_olocked(proc, tr->target.handle,
						     true);
			if (ref) {
				//通过binder_ref类型的ref,可以找到指向的唯一的binder_node类型的node,即服务端
				//target_proc此处被赋值，为当前node所在的进程
				target_node = binder_get_node_refs_for_txn(
						ref->node, &target_proc,
						&return_error);
			} else {
				//handle值无效
				return_error = BR_FAILED_REPLY;
			}
			binder_proc_unlock(proc);
		} else {//假如传输的是binder服务对象，即进行服务的注册,需要找到serviceManager
			mutex_lock(&context->context_mgr_node_lock);
			//获取serviceManager的binder_node，此时target_node为serviceManager的binder_node
			target_node = context->binder_context_mgr_node;
			if (target_node)//找到target_node对应的target_proc
				target_node = binder_get_node_refs_for_txn(
						target_node, &target_proc,
						&return_error);
			else
				return_error = BR_DEAD_REPLY;
			mutex_unlock(&context->context_mgr_node_lock);
			if (target_node && target_proc == proc) {
				//目标进程和发起transaction的进程为同一进程时,返回错误
				//(既然是同一个进程直接调用不就好了吗?)
				return_error = BR_FAILED_REPLY;
				....
				goto err_invalid_target_handle;
			}
		}
		if (!target_node) {
		    //target_node为空时,即服务已死	
			...
			goto err_dead_binder;
		}
	    //至此，无论是服务注册，还是客户请求服务，都确定了target_proc(serviceManager或者client请求的服务)
	    //以及对应的binder_node
		binder_inner_proc_lock(proc);
		//当transaction为同步模式且transaction_stack不为空时
		//transaction_stack不为空说明有需要处理的事务，此时要确认是否有事务的发起者是目标进程．
		if (!(tr->flags & TF_ONE_WAY) && thread->transaction_stack) {
			struct binder_transaction *tmp;
			tmp = thread->transaction_stack;
			//to_thread指向处理该transaction的线程，假如不等于当前thread则报错
			if (tmp->to_thread != thread) {
			    ...	
				binder_inner_proc_unlock(proc);
				return_error = BR_FAILED_REPLY;
				...
				goto err_bad_call_stack;
			}
			//遍历transaction栈,获取处理该事务的线程。紧接着检查线程所在进程是否为目标进程(target_proc)
			//找到则将该事务的线程设置为目标线程(target_thread),否则，将从当前transaction依赖的transaction继续往下找。
			while (tmp) {
				struct binder_thread *from;
				spin_lock(&tmp->lock);
				//找到发起当前transaction的线程。
				from = tmp->from;
				//检查发起线程是否为空，并检查线程所在的进程是否是target_proc(node所在进程或service_manager)
				//如果是,target_thread指向线程from，并且增加线程的tmp_ref，表明该线程正在临时使用。
				if (from && from->proc == target_proc) {
					atomic_inc(&from->tmp_ref);
					target_thread = from;
					spin_unlock(&tmp->lock);
					break;
				}
				spin_unlock(&tmp->lock);
				//将当前transaction替换为依赖的transaction。
				tmp = tmp->from_parent;
			}
		}
		binder_inner_proc_unlock(proc);
	}
    ...
    //分配一个新的transaction *t，初始化并将它最终加入到栈中。
	t = kzalloc(sizeof(*t), GFP_KERNEL);
	if (t == NULL) {
		return_error = BR_FAILED_REPLY;
		...
		goto err_alloc_t_failed;
	}
	//binder_stats的obj_created数组自增,binder_stats用于统计新建obj的数量
	binder_stats_created(BINDER_STAT_TRANSACTION);
	spin_lock_init(&t->lock);
    //分配binder_work
	tcomplete = kzalloc(sizeof(*tcomplete), GFP_KERNEL);
	if (tcomplete == NULL) {
		return_error = BR_FAILED_REPLY;
		...
		goto err_alloc_tcomplete_failed;
	}
	binder_stats_created(BINDER_STAT_TRANSACTION_COMPLETE);
	...
	//当协议为BC_TRANSACTION以及为同步模式时，t事务的发起线程设置为当前线程thread,异步就设置为NULL
	if (!reply && !(tr->flags & TF_ONE_WAY))
		t->from = thread;
	else
		t->from = NULL;
	t->sender_euid = task_euid(proc->tsk);
	//binder_transaction t的处理进程和线程就是target_proc以及target_thread
	t->to_proc = target_proc;
	t->to_thread = target_thread;
	t->code = tr->code;
	t->flags = tr->flags;
	if (!(t->flags & TF_ONE_WAY) &&
	    binder_supported_policy(current->policy)) {
		//继承原有的策略
		t->priority.sched_policy = current->policy;
		t->priority.prio = current->normal_prio;
	} else {
		//设置为默认权限
		t->priority = target_proc->default_priority;
	}
    //为transaction分配buffer,根据上文分析,binder_alloc_new_buf将用户空间以及内核空间映射到物理页面上.
    //且t->buffer是在目标进程(target_proc)中分配的.所以后续copy_from_user到t->buffer时，就涉及到一次拷贝过程
	t->buffer = binder_alloc_new_buf(&target_proc->alloc, tr->data_size,
		tr->offsets_size, extra_buffers_size,
		!reply && (t->flags & TF_ONE_WAY));
	if (IS_ERR(t->buffer)) {
	    ...	
		goto err_binder_alloc_buf_failed;
	}
	t->buffer->allow_user_free = 0;
	t->buffer->debug_id = t->debug_id;
	t->buffer->transaction = t;
	//正在使用该内核缓冲区的binder实体是binder_node或者是serviceManager的binder_node
	t->buffer->target_node = target_node;
	//off_start指向的是Binder对象
	off_start = (binder_size_t *)(t->buffer->data +
				      ALIGN(tr->data_size, sizeof(void *)));
	offp = off_start;
    //从用户空间的transaction数据缓冲区拷贝到target_proc的buffer中,这里即一次拷贝流程,
    //将数据从进程A的用户空间拷贝到进程B的内核空间,又B的内核空间和用户空间相互映射,即一次拷贝到B的用户空间中.从client角度，即将数据拷贝到了server端.
	if (copy_from_user(t->buffer->data, (const void __user *)(uintptr_t)
			   tr->data.ptr.buffer, tr->data_size)) {
	    ...//错误处理	
		goto err_copy_data_failed;
	}
	if (copy_from_user(offp, (const void __user *)(uintptr_t)
			   tr->data.ptr.offsets, tr->offsets_size)) {
	    ...//错误处理	
		goto err_copy_data_failed;
	}
    ...	
	off_end = (void *)off_start + tr->offsets_size;
	sg_bufp = (u8 *)(PTR_ALIGN(off_end, sizeof(void *)));
	sg_buf_end = sg_bufp + extra_buffers_size;
	off_min = 0;
	//遍历处理跨进程拷贝到目标进程中的Binder对象
	for (; offp < off_end; offp++) {
		struct binder_object_header *hdr;
		size_t object_size = binder_validate_object(t->buffer, *offp);
		if (object_size == 0 || *offp < off_min) {
		    ...//错误处理	
			goto err_bad_offset;
		}
		hdr = (struct binder_object_header *)(t->buffer->data + *offp);
		off_min = *offp + object_size;
		switch (hdr->type) {
		//Binder服务端
		case BINDER_TYPE_BINDER:
		case BINDER_TYPE_WEAK_BINDER: {
			struct flat_binder_object *fp;
            //计算出flat_binder_object,这是上层传输的结构
			fp = to_flat_binder_object(hdr);
			//将binder_node数据转化为binder_ref
			ret = binder_translate_binder(fp, t, thread);
			if (ret < 0) {
			    ...//错误处理	
				goto err_translate_failed;
			}
		} break;
		//Binder代理端
		case BINDER_TYPE_HANDLE:
		case BINDER_TYPE_WEAK_HANDLE: {
			struct flat_binder_object *fp;
			fp = to_flat_binder_object(hdr);
			ret = binder_translate_handle(fp, t, thread);
			if (ret < 0) {
			    ...//错误处理	
				goto err_translate_failed;
			}
		} break;

	    ...	
		default:
			...//错误处理	
			goto err_bad_object_type;
		}
	}
	//binder_work将类型设置为BINDER_WORK_TRANSACTION_COMPLETE。
	tcomplete->type = BINDER_WORK_TRANSACTION_COMPLETE;
	//binder_transaciton的work的type类型设置为BINDER_WORK_TRANSACTION。牢记这是在目标进程
	t->work.type = BINDER_WORK_TRANSACTION;

	if (reply) {
	    ...	
	} else if (!(t->flags & TF_ONE_WAY)) {
		binder_inner_proc_lock(proc);
		//将tcomplete加入到当前线程(client)的todo任务列表中,当进程被唤醒时会进行处理(即唤醒的时候，
		//表明transaciton工作已经完成了(BINDER_WORK_TRANSACTION_COMPLETE))
		binder_enqueue_deferred_thread_work_ilocked(thread, tcomplete);
		t->need_reply = 1;
		//将t加入到当前线程的transaction_stack的栈顶
		t->from_parent = thread->transaction_stack;
		thread->transaction_stack = t;
		binder_inner_proc_unlock(proc);
		//刚才先把tcomplete放到当前线程，却把要处理的t->work放入了target_thread的todo列表中
		//并在最后，唤醒目标线程，即让server去处理．假如此时target_thread为空，会从目标进程中挑选一个作为
		//目标线程
		if (!binder_proc_transaction(t, target_proc, target_thread)) {
			binder_inner_proc_lock(proc);
			binder_pop_transaction_ilocked(thread, t);
			binder_inner_proc_unlock(proc);
			goto err_dead_proc_or_thread;
		}
	} else {//异步
	    //仅仅是将tcomplete加入到线程thread的todo任务列表中,而不去唤醒目标线程！
		binder_enqueue_thread_work(thread, tcomplete);
		if (!binder_proc_transaction(t, target_proc, NULL))
			goto err_dead_proc_or_thread;
	}
	//使用完毕后，将target_thread的临时标志去掉，表明线程已经用完了
	if (target_thread)
		binder_thread_dec_tmpref(target_thread);
	binder_proc_dec_tmpref(target_proc);
	if (target_node)
		binder_dec_node_tmpref(target_node);
	smp_wmb();
	WRITE_ONCE(e->debug_id_done, t_debug_id);
	return;
    ...//错误处理
}
```

上述过程很长,可以进行一下简述:

1. 确定目标进程．通过client用户空间的`binder_transaciton_data`类型的tr中的数据,确认目标进程到底是什么，假如tr有target.handle这一属性，则确认是由client发起的，目的是与服务通信，那么`target_proc`就为server．假如不存在这一属性，那么确认是有服务发起的，目的是注册服务，那么`target_proc`就为serviceManager.
2. 确定目标线程．遍历当前进程的事务栈，假如当前已经有目标进程的线程发起的事务，那么会把目标进程的该线程定为目标线程，即让目标进程处理事务时，还是让该线程来进行处理．当然，很可能当前线程并没有目标进程的线程(因为可能是client第一次请求服务)，那么`target_thread`会在后续的时候，由方法binder_select_thread_ilocked(proc)在目标进程中挑选出一个线程作为目标线程．这个线程是在目标进程的`waiting_threads`中挑选的．
3. 分配`binder_transaction`类型的t以及`binder_work`的tcomplete.在t中将赋值，如目标进程，目标线程，并调用`binder_alloc_new_buf`将目标进程的用户空间与内核空间进行映射，将映射地址也赋值到t中．更重要的是，通过一次拷贝，将数据拷贝到了目标进程中．
4. 拷贝完成后，基础数据不需要改动，但是binder对象内容需要修改．首先会通过转换变为`flat_binder_object`类型,并将server类型改为`BINDER_TYPE_HANDLE`,将client类型改为`BINDER_TYPE_BINDER`,这样的话，目标进程读取上来的时候类型就会被修改．
5. 将t的工作类型定义为`BINDER_WORK_TRANSACTION`,而将tcomplete的类型定义为`BINDER_WORK_TRANSACTION_COMPLETE`.
首先将tcomplete加入到本进程的todo列表，意图是当目标进程处理完工作通知我，就会处理tcomplete这个工作．紧接着
把t放入到client的事务栈(`transaction_stack`)中, 再把t的`binder_work`(要处理的工作项)放在了目标进程的todo列表中，表明这是目标进程要处理的工作，并唤醒了server进程(server进程应该之前是休眠等待唤醒处理事务).

接着看下进行类型转换的流程:

```c++
//linux-4.9/drivers/android/binder.c
static int binder_translate_binder(struct flat_binder_object *fp,
				   struct binder_transaction *t,
				   struct binder_thread *thread)
{
	struct binder_node *node;
	struct binder_proc *proc = thread->proc;
	struct binder_proc *target_proc = t->to_proc;
	struct binder_ref_data rdata;
	int ret = 0;
    //在binder_proc进程中的nodes红黑树中，根据地址(fp->binder)找到flat_binder_object
	node = binder_get_node(proc, fp->binder);
	if (!node) {
	    //假如找不到则新建一个binder_node,新建的node会加入服务进程的nodes红黑树中
	    //服务在注册服务时，就会在服务进程中新建一个binder_node到nodes红黑树中
		node = binder_new_node(proc, fp);
		if (!node)
			return -ENOMEM;
	}
	if (fp->cookie != node->cookie) {
	    ...	
		ret = -EINVA;
		goto done;
	}
	//尝试获取node对应的binder_ref,如果找不到,则会在红黑树binder_ref_desc以及binder_ref_node中增加binder_ref
	//当服务使用addService时,对应的target_proc为ServiceManager,即在ServiceManager
	ret = binder_inc_ref_for_node(target_proc, node,
			fp->hdr.type == BINDER_TYPE_BINDER,
			&thread->todo, &rdata);
	if (ret)
		goto done;
    //当上层设定的类型为BINDER_TYPE_BINDER时，即服务时，会将类型改为BINDER_TYPE_HANDLE
	if (fp->hdr.type == BINDER_TYPE_BINDER)
		fp->hdr.type = BINDER_TYPE_HANDLE;
	else//其余的都改成BINDER_TYPE_WEAK_HANDLE
		fp->hdr.type = BINDER_TYPE_WEAK_HANDLE;
	fp->binder = 0;
	//将binder_ref对应的binder_ref_data中的desc值赋值给handle
	fp->handle = rdata.desc;
	fp->cookie = 0;
    ...
done:
	binder_put_node(node);
	return ret;
}

static struct binder_node *binder_get_node(struct binder_proc *proc,
					   binder_uintptr_t ptr)
{
	struct binder_node *node;
	binder_inner_proc_lock(proc);
	node = binder_get_node_ilocked(proc, ptr);
	binder_inner_proc_unlock(proc);
	return node;
}

static struct binder_node *binder_get_node_ilocked(struct binder_proc *proc,
						   binder_uintptr_t ptr)
{
    //从进程binder_proc中的nodes红黑树中获取根节点
	struct rb_node *n = proc->nodes.rb_node;
	struct binder_node *node;
	assert_spin_locked(&proc->inner_lock);
    //在nodes红黑树中找到对应的node并返回
	while (n) {
		node = rb_entry(n, struct binder_node, rb_node);

		if (ptr < node->ptr)
			n = n->rb_left;
		else if (ptr > node->ptr)
			n = n->rb_right;
		else {
			//增加node的tmp_refs计数器,表明正在使用
			binder_inc_node_tmpref_ilocked(node);
			return node;
		}
    }
}
```

总结一下，`binder_translate_binder`从上层获取的`flat_binder_object`对象fp，首先从进程红黑树nodes中找对应的`binder_node`，如果找不到就新建一个。紧接着会调用`binder_inc_ref_for_node`来增加引用。最后会将`flat_binder_object`的类型，进行转换，如果是`BINDER_TYPE_BINDER`则改为`BINDER_TYPE_HANDLE`,其余的改为`BINDER_TYPE_WEAK_HANDLE`。当Binder服务传输服务本身到驱动，经过`binder_translate_binder`后修改类型为`BINDER_TYPE_HANDLE`。

```c++
//frameworks/native/cmds/servicemanager/binder.c
uint32_t bio_get_ref(struct binder_io *bio)
{
    struct flat_binder_object *obj;
    obj = _bio_get_obj(bio);
    if (!obj)
        return 0;
    //返回handle值
    if (obj->hdr.type == BINDER_TYPE_HANDLE)
        return obj->handle;
    return 0;
}
```

从binder红黑树节点角度看,当服务选择了addService时,自身进程会创建一个`binder_node`节点加入到nodes红黑树中,紧接着,`target_proc`,即serviceManager也会创建与之对应的`binder_ref`节点加入到自身的`refs_by_node`红黑树中.

对于client端请求服务时，则会调用`binder_translate_handle`，流程也十分类似，即当类型为`BINDER_TYPE_HANDLE`时，会改成`BINDER_TYPE_BINDER`

```c++
//linux-4.9/drivers/android/binder.c
static int binder_translate_handle(struct flat_binder_object *fp,
				   struct binder_transaction *t,
				   struct binder_thread *thread)
{
	struct binder_proc *proc = thread->proc;
	struct binder_proc *target_proc = t->to_proc;
	struct binder_node *node;
	struct binder_ref_data src_rdata;
	int ret = 0;
    //首先从进程的refs_by_desc红黑树中找到binder_ref节点，从而找到binder_node
    //client的refs_by_desc是ServiceManager插入的节点．
	node = binder_get_node_from_ref(proc, fp->handle,
			fp->hdr.type == BINDER_TYPE_HANDLE, &src_rdata);
	if (!node) {
		//找不到node
		return -EINVAL;
	}
    //.....	
	binder_node_lock(node);
	if (node->proc == target_proc) {
	    //假如为BINDER_TYPE_HANDLE，则改为BINDER_TYPE_BINDER
		if (fp->hdr.type == BINDER_TYPE_HANDLE)
			fp->hdr.type = BINDER_TYPE_BINDER;
		else//其余的改为BINDER_TYPE_WEAK_BINDER
			fp->hdr.type = BINDER_TYPE_WEAK_BINDER;
		//将对应的binder_node地址都赋值到flat_binder_object中。
		fp->binder = node->ptr;
		fp->cookie = node->cookie;
		if (node->proc)
			binder_inner_proc_lock(node->proc);
		binder_inc_node_nilocked(node,
					 fp->hdr.type == BINDER_TYPE_BINDER,
					 0, NULL);
		if (node->proc)
			binder_inner_proc_unlock(node->proc);
		binder_node_unlock(node);
	} else {
		struct binder_ref_data dest_rdata;

		binder_node_unlock(node);
		ret = binder_inc_ref_for_node(target_proc, node,
				fp->hdr.type == BINDER_TYPE_HANDLE,
				NULL, &dest_rdata);
		if (ret)
			goto done;

		fp->binder = 0;
		fp->handle = dest_rdata.desc;
		fp->cookie = 0;
	}
done:
	binder_put_node(node);
	return ret;
}
```


### 2.7.3 `BR_TRANSACTION_COMPLETE && BR_TRANSACTION`

当`binder_ioctl_write_read`完成了写操作后(`binder_thread_write`),会有个等待结果并读取的动作．

```c++
//linux-4.9/drivers/android/binder.c
static int binder_ioctl_write_read(struct file *filp,
				unsigned int cmd, unsigned long arg,
				struct binder_thread *thread)
{
    ...//完成写操作
    //bwr.read_size是由上层IPCThreadState决定的,默认均为接收
    //即bwr.read_size为mIn.dataCapacity()
    if (bwr.read_size > 0) {
        //binder_thread_read为接下来要分析的重点
		ret = binder_thread_read(proc, thread, bwr.read_buffer,
					 bwr.read_size,
					 &bwr.read_consumed,
					 filp->f_flags & O_NONBLOCK);
		binder_inner_proc_lock(proc);
		if (!binder_worklist_empty_ilocked(&proc->todo))
			binder_wakeup_proc_ilocked(proc);
		binder_inner_proc_unlock(proc);
		if (ret < 0) {
			if (copy_to_user(ubuf, &bwr, sizeof(bwr)))
				ret = -EFAULT;
			goto out;
		}
	}
    ...
}
```

`binder_thread_read`的proc参数指向binder驱动进程，thread为进程中的其中一个线程。`binder_buffer`,size,`consumed`分别对应的是bwr中的`read_buffer`,`read_size`以及`read_consumed`。

```c++
//linux-4.9/drivers/android/binder.c
static int binder_thread_read(struct binder_proc *proc,
			      struct binder_thread *thread,
			      binder_uintptr_t binder_buffer, size_t size,
			      binder_size_t *consumed, int non_block)
{
	void __user *buffer = (void __user *)(uintptr_t)binder_buffer;
	void __user *ptr = buffer + *consumed;
	void __user *end = buffer + size;

	int ret = 0;
	int wait_for_proc_work;
	if (*consumed == 0) {
		if (put_user(BR_NOOP, (uint32_t __user *)ptr))
			return -EFAULT;
		ptr += sizeof(uint32_t);
	}

retry:
	binder_inner_proc_lock(proc);
	//binder_available_for_proc_work_ilocked检查假如thread的状态为
	//BINDER_LOOPER_STATE_ENTERED或者BINDER_LOOPER_STATE_REGISTERED
	//且thread的todo任务列表以及事务栈transaciton_stack为空才返回true!
	wait_for_proc_work = binder_available_for_proc_work_ilocked(thread);
	binder_inner_proc_unlock(proc);
    //此时改变线程的状态为BINDER_LOOPER_STATE_WAITING
	thread->looper |= BINDER_LOOPER_STATE_WAITING;
    ...	
	if (non_block) {
		//1.检查thread的process_todo标志(todo任务列表是否需要处理)
		//2.或者检查thread的looper_need_return是否需要退出驱动？
		//3.当第二参数置true时，检查todo列表是否为非空
		//满足上述3个条件其1，都会返回true
		if (!binder_has_work(thread, wait_for_proc_work))
			ret = -EAGAIN;
	} else {
		//binder_wait_for_work调用prepare_to_wait将自身加入wait队列
		//紧接着调用schedule,本进程的thread开始休眠等待唤醒
		ret = binder_wait_for_work(thread, wait_for_proc_work);
	}
	//去掉BINDER_LOOPER_STATE_WAITING标记,此时已经被唤醒了!
	thread->looper &= ~BINDER_LOOPER_STATE_WAITING;

	if (ret)
		return ret;
    //开始处理信息了
	while (1) {
		uint32_t cmd;
		struct binder_transaction_data tr;
		struct binder_work *w = NULL;
		struct list_head *list = NULL;
		struct binder_transaction *t = NULL;
		struct binder_thread *t_from;

		binder_inner_proc_lock(proc);
		//list获取线程或者进程的todo任务列表
		if (!binder_worklist_empty_ilocked(&thread->todo))
			list = &thread->todo;
		else if (!binder_worklist_empty_ilocked(&proc->todo) &&
			   wait_for_proc_work)
			list = &proc->todo;
		else {
			binder_inner_proc_unlock(proc);
			if (ptr - buffer == 4 && !thread->looper_need_return)
				goto retry;
			break;
		}

		if (end - ptr < sizeof(tr) + 4) {
			binder_inner_proc_unlock(proc);
			break;
		}
		//获取list的头部binder_work
		w = binder_dequeue_work_head_ilocked(list);
		//thread->todo为空时，则设置process_todo设置为false，不需要处理thread的todo列表
		if (binder_worklist_empty_ilocked(&thread->todo))
			thread->process_todo = false;
		switch (w->type) {
	    ...
        case BINDER_WORK_TRANSACTION: {
        //如果站在server角度看，todo列表中的是BINDER_WORK_TRANSACTION，即获取到了client过来的binder_transaction
			binder_inner_proc_unlock(proc);
			t = container_of(w, struct binder_transaction, work);
		} break;
		//如果在client角度看，当前thread的todo列表里第一个是BINDER_WORK_TRANSACTION_COMPLETE
	    case BINDER_WORK_TRANSACTION_COMPLETE: {
			binder_inner_proc_unlock(proc);
			cmd = BR_TRANSACTION_COMPLETE;
			//将BR_TRANSACtiON_COMPLETE返回到用户空间中。
			//至此，完成了从驱动到用户空间，返回BR_TRANSACTION_COMPLETE到proxy端
			if (put_user(cmd, (uint32_t __user *)ptr))
				return -EFAULT;
			ptr += sizeof(uint32_t);

			binder_stat_br(proc, thread, cmd);
			kfree(w);   
			binder_stats_deleted(BINDER_STAT_TRANSACTION_COMPLETE);
		} break;
	    ...//忽略其他命令
		}
		if (!t)
			continue;
		//t存在时，server通过binder_transaction获取到了target_node
		if (t->buffer->target_node) {
		    //获取正在使用该数据缓存区的binder_node 
			struct binder_node *target_node = t->buffer->target_node;
			struct binder_priority node_prio;
            //ptr指向的是weakref_impl地址
			tr.target.ptr = target_node->ptr;
			//获取用户空间service的地址(IBinder的地址)
			tr.cookie =  target_node->cookie;
			node_prio.sched_policy = target_node->sched_policy;
			node_prio.prio = target_node->min_priority;
			binder_transaction_priority(current, t, node_prio,
						    target_node->inherit_rt);
			cmd = BR_TRANSACTION;
		} else {//不存在使用的binder_node时，初始化为0
			tr.target.ptr = 0;
			tr.cookie = 0;
			cmd = BR_REPLY;
		}
		tr.code = t->code;
		tr.flags = t->flags;
		tr.sender_euid = from_kuid(current_user_ns(), t->sender_euid);
        //找到发起事务的线程t_from
		t_from = binder_get_txn_from(t);
		if (t_from) {
			//获取t_from所在进程的进程信息sender
			struct task_struct *sender = t_from->proc->tsk;
            
			tr.sender_pid = task_tgid_nr_ns(sender,
							task_active_pid_ns(current));
		} else {
			tr.sender_pid = 0;
		}

		tr.data_size = t->buffer->data_size;
		tr.offsets_size = t->buffer->offsets_size;
		tr.data.ptr.buffer = (binder_uintptr_t)
			((uintptr_t)t->buffer->data +
			binder_alloc_get_user_buffer_offset(&proc->alloc));
		tr.data.ptr.offsets = tr.data.ptr.buffer +
					ALIGN(t->buffer->data_size,
					    sizeof(void *));
        //将BR_TRANSACTION传到服务的用户空间中
		if (put_user(cmd, (uint32_t __user *)ptr)) {
			if (t_from)
				binder_thread_dec_tmpref(t_from);
			binder_cleanup_transaction(t, "put_user failed",
						   BR_FAILED_REPLY);
			return -EFAULT;
		}
		ptr += sizeof(uint32_t);
		//将数据binder_transaction_data也拷贝到服务端
		if (copy_to_user(ptr, &tr, sizeof(tr))) {
			if (t_from)
				binder_thread_dec_tmpref(t_from);
			binder_cleanup_transaction(t, "copy_to_user failed",
						   BR_FAILED_REPLY);
			return -EFAULT;
		}
		ptr += sizeof(tr);
        ...
		binder_stat_br(proc, thread, cmd);
	    ...	
		//清除t_from线程的正在使用的标志
		if (t_from)
			binder_thread_dec_tmpref(t_from);
		t->buffer->allow_user_free = 1;
		if (cmd == BR_TRANSACTION && !(t->flags & TF_ONE_WAY)) {
			binder_inner_proc_lock(thread->proc);
			t->to_parent = thread->transaction_stack;
			t->to_thread = thread;
			thread->transaction_stack = t;
			binder_inner_proc_unlock(thread->proc);
		} else {
			binder_free_transaction(t);
		}
		break;
	}

done:

	*consumed = ptr - buffer;
	binder_inner_proc_lock(proc);
	//假如进程没有要求注册新线程，且waiting_threads为空,满足下列条件时，
	//驱动会发一个BR_SPAWN_LOOPER要求新建一个线程处理
	if (proc->requested_threads == 0 &&
	    list_empty(&thread->proc->waiting_threads) &&
	    proc->requested_threads_started < proc->max_threads &&
	    (thread->looper & (BINDER_LOOPER_STATE_REGISTERED |
	     BINDER_LOOPER_STATE_ENTERED)) /* the user-space code fails to */
		proc->requested_threads++;
		binder_inner_proc_unlock(proc);
		if (put_user(BR_SPAWN_LOOPER, (uint32_t __user *)buffer))
			return -EFAULT;
		binder_stat_br(proc, thread, BR_SPAWN_LOOPER);
	} else
		binder_inner_proc_unlock(proc);
	return 0;
}
```

`binder_thread_read`其实涉及了两个进程的处理过程，第一是client，当完成了`binder_thread_write`后，会陷入休眠状态，等待处理事务栈里的内容．当被唤醒后，会遍历todo列表的work项，类型为`BINDER_WORK_TRANSACTION_COMPLETE`,并将`BR_TRANSACTION_COMPLETE`上传到client的上层中．表明驱动已经知道了，给出了反馈．第二是从server的角度，server会一直监听binder驱动，当client写数据唤醒了server后，也会立即遍历todo列表的work项，从`binder_work`中获取到`binder_transaciton`,再从`binder_transaciton`中获取到`binder_node`，并获取到更多的信息，如上层的IBinder地址以及`weakref_impl`的地址．并且cmd设置为`BR_TRANSACTION`,从驱动将数据返回到server的用户空间中．至此完成了驱动到client/server的反馈．

### 2.7.4 `BC_REPLY && BR_TRANSACTION_COMPLETE`

从server角度看，当消息上来时，会通过executecommand进行处理:


```c++
//frameworks/native/libs/binder/IPCThreadState.cpp
status_t IPCThreadState::executeCommand(int32_t cmd)
{
...
case BR_TRANSACTION:
{
    binder_transaction_data tr;
    //将内核传来的binder_transaction_data读取上来
    result = mIn.read(&tr, sizeof(tr));
    if (result != NO_ERROR) break;
    Parcel buffer;
    buffer.ipcSetDataReference(
        reinterpret_cast<const uint8_t*>(tr.data.ptr.buffer),
        tr.data_size,
        reinterpret_cast<const binder_size_t*>(tr.data.ptr.offsets),
        tr.offsets_size/sizeof(binder_size_t), freeBuffer, this);

    const pid_t origPid = mCallingPid;
    const uid_t origUid = mCallingUid;
    const int32_t origStrictModePolicy = mStrictModePolicy;
    const int32_t origTransactionBinderFlags = mLastTransactionBinderFlags;

    mCallingPid = tr.sender_pid;
    mCallingUid = tr.sender_euid;
    mLastTransactionBinderFlags = tr.flags;
    
    Parcel reply;
    status_t error;
    
    if (tr.target.ptr) {
        //增加强引用计数，因为这时候多了一个client了
        if (reinterpret_cast<RefBase::weakref_type*>(
                tr.target.ptr)->attemptIncStrong(this)) {
            error = reinterpret_cast<BBinder*>(tr.cookie)->transact(tr.code, buffer,
                    &reply, tr.flags);
            reinterpret_cast<BBinder*>(tr.cookie)->decStrong(this);
        } else {
            error = UNKNOWN_TRANSACTION;
        }

    } else {
        error = the_context_object->transact(tr.code, buffer, &reply, tr.flags);
    }

    if ((tr.flags & TF_ONE_WAY) == 0) {
        if (error < NO_ERROR) reply.setError(error);
        //发送BC_REPLY到驱动，表明服务用户层已经收到了消息
        sendReply(reply, 0);
    } else {
        LOG_ONEWAY("NOT sending reply to %d!", mCallingPid);
    }

    mCallingPid = origPid;
    mCallingUid = origUid;
    mStrictModePolicy = origStrictModePolicy;
    mLastTransactionBinderFlags = origTransactionBinderFlags;
}
break;
```

```c++
//frameworks/native/libs/binder/IPCThreadState.cpp
status_t IPCThreadState::sendReply(const Parcel& reply, uint32_t flags)
{
    status_t err;
    status_t statusBuffer;
    //这里给反馈BC_REPLY到驱动
    err = writeTransactionData(BC_REPLY, flags, -1, 0, reply, &statusBuffer);
    if (err < NO_ERROR) return err;
    //等待反馈
    return waitForResponse(NULL, NULL);
}
```

这里不得不回到之前的`binder_transaciton`了．

```c++
//linux-4.9/drivers/android/binder.c
static void binder_transaction(struct binder_proc *proc,
			       struct binder_thread *thread,
			       struct binder_transaction_data *tr, int reply,
			       binder_size_t extra_buffers_size)
{
    ...//前面已分析
	if (reply) {
		binder_inner_proc_lock(proc);
		in_reply_to = thread->transaction_stack;
		if (in_reply_to == NULL) {//当前的事务栈为空
			binder_inner_proc_unlock(proc);
			return_error = BR_FAILED_REPLY;
			return_error_param = -EPROTO;
			return_error_line = __LINE__;
			goto err_empty_call_stack;
		}
		//事务栈的binder_transaction要处理的线程和当前线程不一致
		if (in_reply_to->to_thread != thread) {
			spin_lock(&in_reply_to->lock);
			spin_unlock(&in_reply_to->lock);
			binder_inner_proc_unlock(proc);
			return_error = BR_FAILED_REPLY;
			return_error_param = -EPROTO;
			return_error_line = __LINE__;
			in_reply_to = NULL;
			goto err_bad_call_stack;
		}
		thread->transaction_stack = in_reply_to->to_parent;
		binder_inner_proc_unlock(proc);
		//从事务in_reply_to中获取到处理线程target_thread，即client的发起线程．
		target_thread = binder_get_txn_from_and_acq_inner(in_reply_to);
		if (target_thread == NULL) {
			return_error = BR_DEAD_REPLY;
			return_error_line = __LINE__;
			goto err_dead_binder;
		}
		if (target_thread->transaction_stack != in_reply_to) {
		    ...	
			binder_inner_proc_unlock(target_thread->proc);
			return_error = BR_FAILED_REPLY;
			return_error_param = -EPROTO;
			return_error_line = __LINE__;
			in_reply_to = NULL;
			target_thread = NULL;
			goto err_dead_binder;
		}
		//获取target_proc目标进程，即client的进程
		target_proc = target_thread->proc;
		target_proc->tmp_ref++;
		binder_inner_proc_unlock(target_thread->proc);
	}
    
    if (target_thread)
		e->to_thread = target_thread->pid;
	e->to_proc = target_proc->pid;
    //又新建了一个新的binder_transaction t,用于放入target_proc中
	t = kzalloc(sizeof(*t), GFP_KERNEL);
	if (t == NULL) {
		return_error = BR_FAILED_REPLY;
		return_error_param = -ENOMEM;
		return_error_line = __LINE__;
		goto err_alloc_t_failed;
	}
	binder_stats_created(BINDER_STAT_TRANSACTION);
	spin_lock_init(&t->lock);
    //新建了tcomplete，用于反馈到server的用户空间
	tcomplete = kzalloc(sizeof(*tcomplete), GFP_KERNEL);
	if (tcomplete == NULL) {
		return_error = BR_FAILED_REPLY;
		return_error_param = -ENOMEM;
		return_error_line = __LINE__;
		goto err_alloc_tcomplete_failed;
	}
	binder_stats_created(BINDER_STAT_TRANSACTION_COMPLETE);

	t->debug_id = t_debug_id;
    ....
    //填充t的信息，并将client的用户空间和内核空间进行映射，然后进行一次拷贝
    //.....
    //处理binder对象转换工作
    tcomplete->type = BINDER_WORK_TRANSACTION_COMPLETE;
	t->work.type = BINDER_WORK_TRANSACTION;
    if (reply) {
		//将tcomplete插入到当前线程,即server的todo列表中
		binder_enqueue_thread_work(thread, tcomplete);
		binder_inner_proc_lock(target_proc);
		if (target_thread->is_dead) {
			binder_inner_proc_unlock(target_proc);
			goto err_dead_proc_or_thread;
		}
		binder_pop_transaction_ilocked(target_thread, in_reply_to);
		//将t插入到client的todo列表中
		binder_enqueue_thread_work_ilocked(target_thread, &t->work);
		binder_inner_proc_unlock(target_proc);
		//唤醒client线程
		wake_up_interruptible_sync(&target_thread->wait);
		binder_restore_priority(current, in_reply_to->saved_priority);
		binder_free_transaction(in_reply_to);
	}	
    ...	
```


### 2.7.5 BR_REPLY

client线程在`binder_thread_read`会不断读取信息，

```c++
//linux-4.9/drivers/android/binder.c
static int binder_thread_read(struct binder_proc *proc,
			      struct binder_thread *thread,
			      binder_uintptr_t binder_buffer, size_t size,
			      binder_size_t *consumed, int non_block)
{
...
if (t->buffer->target_node) {
	struct binder_node *target_node = t->buffer->target_node;
	struct binder_priority node_prio;

	tr.target.ptr = target_node->ptr;
	tr.cookie =  target_node->cookie;
	node_prio.sched_policy = target_node->sched_policy;
	node_prio.prio = target_node->min_priority;
	binder_transaction_priority(current, t, node_prio,
				    target_node->inherit_rt);
	cmd = BR_TRANSACTION;
} else {//t->buffer->target_node为空
	tr.target.ptr = 0;
	tr.cookie = 0;
	cmd = BR_REPLY;
}
...
}
```

此时可以回到上层看如何处理`BR_REPLY`:

```c++
//frameworks/native/libs/binder/IPCThreadState.cpp
status_t IPCThreadState::waitForResponse(Parcel *reply, status_t *acquireResult)
{
    uint32_t cmd;
    int32_t err;

    while (1) {
        if ((err=talkWithDriver()) < NO_ERROR) break;
        err = mIn.errorCheck();
        if (err < NO_ERROR) break;
        if (mIn.dataAvail() == 0) continue;

        cmd = (uint32_t)mIn.readInt32();
        switch (cmd) {
        case BR_REPLY:
            {
                binder_transaction_data tr;
                err = mIn.read(&tr, sizeof(tr));
                if (err != NO_ERROR) goto finish;

                if (reply) {
                    if ((tr.flags & TF_STATUS_CODE) == 0) {
                        //reply中也获取到了server传过来的内容
                        reply->ipcSetDataReference(
                            reinterpret_cast<const uint8_t*>(tr.data.ptr.buffer),
                            tr.data_size,
                            reinterpret_cast<const binder_size_t*>(tr.data.ptr.offsets),
                            tr.offsets_size/sizeof(binder_size_t),
                            freeBuffer, this);
                    } else {
                        err = *reinterpret_cast<const status_t*>(tr.data.ptr.buffer);
                        freeBuffer(NULL,
                            reinterpret_cast<const uint8_t*>(tr.data.ptr.buffer),
                            tr.data_size,
                            reinterpret_cast<const binder_size_t*>(tr.data.ptr.offsets),
                            tr.offsets_size/sizeof(binder_size_t), this);
                    }
                } else {
                    ... 
                }
            }
            goto finish;
        } 
}
```


```
//frameworks/native/libs/binder/Parcel.cpp
void Parcel::ipcSetDataReference(const uint8_t* data, size_t dataSize,
    const binder_size_t* objects, size_t objectsCount, release_func relFunc, void* relCookie)
{
    binder_size_t minOffset = 0;
    freeDataNoInit();
    mError = NO_ERROR;
    mData = const_cast<uint8_t*>(data);
    mDataSize = mDataCapacity = dataSize;
    mDataPos = 0;
    mObjects = const_cast<binder_size_t*>(objects);
    mObjectsSize = mObjectsCapacity = objectsCount;
    mNextObjectHint = 0;
    mObjectsSorted = false;
    mOwner = relFunc;
    mOwnerCookie = relCookie;
    for (size_t i = 0; i < mObjectsSize; i++) {
        binder_size_t offset = mObjects[i];
        if (offset < minOffset) {
            //偏移量不能小于minOffset
            mObjectsSize = 0;
            break;
        }
        minOffset = offset + sizeof(flat_binder_object);
    }
    scanForFds();
}
```

由此，server到client的信息已经填充到Parcel类型的reply中了.再回到上层调用getService中:

```c++
virtual sp<IBinder> getService(const String16& name) const
{
    sp<IBinder> svc = checkService(name);
    if (svc != NULL) return svc;
    ...
}

virtual sp<IBinder> checkService( const String16& name) const
{
    Parcel data, reply;
    data.writeInterfaceToken(IServiceManager::getInterfaceDescriptor());
    data.writeString16(name);
    //通过上述可得，reply即service给到的数据
    remote()->transact(CHECK_SERVICE_TRANSACTION, data, &reply);
    //通过readStrongBinder将Binder对象读出来
    return reply.readStrongBinder();
}
```

参考文献:

1. [听说你Binder机制学的不错，来面试下这几个问题（一）](https://www.jianshu.com/p/adaa1a39a274)
2. [Android系统源代码情景分析]()

