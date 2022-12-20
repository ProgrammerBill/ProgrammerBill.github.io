---
layout:     post
title:      "Android 7.0 Brightness亮度调节流程分析"
summary:    '"Android Brightness"'
date:       2018-10-16 17:38:00
author:     "Bill"
header-img: "img/bill/header-posts/2018-10-16.jpg"
catalog: true
tags:
    - android
    - DisplayManagerService
---



<!-- vim-markdown-toc GFM -->

* [1. 背景](#1-背景)
* [2. FrameWork调节亮度流程](#2-framework调节亮度流程)
	* [2.1 亮度相关Service启动流程](#21-亮度相关service启动流程)
	* [2.2 BrightnessDialog调用流程](#22-brightnessdialog调用流程)
		* [2.2.1 BrightnessDialog](#221-brightnessdialog)
		* [2.2.2 BrightnessController && BrightnessObserver](#222-brightnesscontroller--brightnessobserver)
* [3.Brightness && PowermanagerService](#3brightness--powermanagerservice)
	* [3.1 IPowerManager的Binder设计](#31-ipowermanager的binder设计)
	* [3.2 PMS的亮度控制](#32-pms的亮度控制)
	* [3.3 DMS的亮度控制](#33-dms的亮度控制)
	* [3.5 LightImpl](#35-lightimpl)
	* [3.6 Lights的Native实现](#36-lights的native实现)
	* [3.7 Lights的Hal层分析](#37-lights的hal层分析)

<!-- vim-markdown-toc -->

# 1. 背景

Android 7.0 盒子需要支持双屏同时输出，通过HDMI的显示器不支持亮度调节，而LCD输出需要支持亮度调节，因此有了解亮度调节是如何进行调节的需求。负责显示的同事经过交流后，提供了一系列节点，"你只需要把这些节点按照这个顺序写就好了啊"。但是作为系统工作者，自然不能随便将写节点的操作放在上层，需要弄清楚整条通路后，再分析哪里是最佳的实现点。

接下来的分析涉及的文件包括:

- frameworks/base/services/java/com/android/server/SystemServer.java
- frameworks/base/services/core/java/com/android/server/SystemServiceManager.java
- frameworks/base/services/core/java/com/android/server/SystemService.java
- frameworks/base/services/core/java/com/android/server/power/PowerManagerService.java
- frameworks/base/services/core/java/com/android/server/display/DisplayManagerService.java
- frameworks/base/packages/SystemUI/src/com/android/systemui/settings/BrightnessDialog.java
- `frameworks/base/services/core/jni/com_android_server_lights_LightsService.cpp`

# 2. FrameWork调节亮度流程

Framework的整个流程如下图所示:

![](/img/bill/in-posts/2018-10-16/1.jpg)

## 2.1 亮度相关Service启动流程

![](/img/bill/in-posts/2018-10-16/2.jpg)

为了要支持亮度调节，需要Android系统的两大服务PMS(PowerManagerService)以及DMS(DisplayManagerService)的支持，它们的启动均在SystemServer启动的流程时开始。而SystemServer为了能够开启这两大服务，需要借助SystemServiceManager的协助。可以看到SystemServer在开启服务的时候都用了类似如下语句:


```java
//SystemServer
private PowerManagerService mPowerManagerService;
private DisplayManagerService mDisplayManagerService;
....
mPowerManagerService = mSystemServiceManager.startService(PowerManagerService.class);
....
mDisplayManagerService = mSystemServiceManager.startService(DisplayManagerService.class);
```

这里有几个巧妙的设计，一是所有服务，都继承了SystemService父类，二是SystemServiceManager通过获取服务名，利用反射最终调用到服务的onStart方法，从而运行服务，所以每个服务观察也可以看出基本实现了onStart这个接口。startService的关键代码如下:

```java
//SystemServiceManager
public <T extends SystemService> T startService(Class<T> serviceClass) {
        try {
            final String name = serviceClass.getName();
            // Create the service.
            ......
            final T service;
            try {
                Constructor<T> constructor = serviceClass.getConstructor(Context.class);
                service = constructor.newInstance(mContext);
            } catch (...) {
            ...//捕获相关异常,包括InstantiationException,
               //IllegalAccessException,NoSuchMethodException,InvocationTargetException 
            } 

            //SystemService维护着一个链表用以保存所有的服务
            mServices.add(service);

            // Start it.
            try {
                service.onStart();
            } catch (RuntimeException ex) {
                ...
            }
            return service;
        } finally {
            ...
        }
    }
```

当DMS被调用后，调用onStart方法，其实现如下：

```java
//DisplayManagerService
@Override
    public void onStart() {
        mHandler.sendEmptyMessage(MSG_REGISTER_DEFAULT_DISPLAY_ADAPTER);
        publishBinderService(Context.DISPLAY_SERVICE, new BinderService(),
                true /*allowIsolated*/);
        publishLocalService(DisplayManagerInternal.class, new LocalService());
    }
```

- 首先MDS发送`MSG_REGISTER_DEFAULT_DISPLAY_ADAPTER`到DisplayManagerHandelr处理，并最终调用到方法registerDefaultDisplayAdapter(),用于注册一个displayAdapter，其中DisplayAdapterListener将会监听DisplayDevice的变化，一旦有增删修改等，就会通知到DMS进行处理。
- DMS还实现两个重要的内部类，LocalService，继承DisplayManagerInternal，另一个是BinderService，继承IDisplayManager.Stub。
- publishBinderService的意图在于能够让其他服务能够通过binder通信与DMS进行通信(publish即公开，公开这个Binder服务),而其实现也可以看出来是将这个BinderService加入到服务台ServiceManager中，以后通过名字即可以找到该binderService,并最终调用到DMS的方法中。

```java
//SystemService
protected final void publishBinderService(String name, IBinder service,
        boolean allowIsolated) {
    ServiceManager.addService(name, service, allowIsolated);
}
```

![](/img/bill/in-posts/2018-10-16/3.jpg)

从这个角度看，BinderService是为了能够让DMS的功能能够通过ServiceManager进行查询并调用，也算是Adapter的用法了。

- publishLocalService的用法与publishBinderService的用法类似，区别是后者是专门注册Binder服务，而前者是注册的本地服务，源码有一段这样的话表明了其设计的用意:

```
 * This class is used in a similar way as ServiceManager, except the services registered here
 * are not Binder objects and are only available in the same process.
```

即在同一个进程的服务，可轻松的调用其他服务的LocalService,由此也引出了PMS是如何调用DMS的本地服务的:

```java
./services/core/java/com/android/server/power/PowerManagerService.java
//PowerManagerService
public void systemReady(IAppOpsService appOps) {
    synchronized (mLock) {
        mDisplayManagerInternal = getLocalService(DisplayManagerInternal.class);
        ....
        // Initialize display power management.
        mDisplayManagerInternal.initPowerManagement(
                mDisplayPowerCallbacks, mHandler, sensorManager);
...
}
```

## 2.2 BrightnessDialog调用流程

从UI角度看，亮度调节主要涉及BrightnessDialog,BrightnessController,BrightnessObserver。其中：

- BrightnessDialog主要负责UI显示，创建BrightnessController
- BrightnessController用于实际控制亮度,根据ToogleSlider的位置设置值调节亮度
- BrightnessObserver用于观测ToggleSlider的变化，并及时反映给BrightnessController


![](/img/bill/in-posts/2018-10-16/4.png)


亮度调节一般可以通过Settings进行调用，其中Settings的`display_settings`布局文件有定义：

```
//Settings
<PreferenceScreen
        android:key="brightness"
        android:title="@string/brightness"
        settings:keywords="@string/keywords_display_brightness_level">
    <intent android:action="android.intent.action.SHOW_BRIGHTNESS_DIALOG" />
</PreferenceScreen> 
```

PreferenceScreen指定intent,在选中的时候即可以发送`android.intent.action.SHOW_BRIGHTNESS_DIALOG`开启Activity，framework中首先用AndroidManifest定义了该Activity:

```xml
//frameworks/base/packages/SystemUI/AndroidManifest.xml
<activity
  android:name=".settings.BrightnessDialog"
  android:label="@string/quick_settings_brightness_dialog_title"
  android:theme="@android:style/Theme.DeviceDefault.Dialog"
  android:finishOnCloseSystemDialogs="true"
  android:launchMode="singleInstance"
  android:excludeFromRecents="true"
  android:exported="true">
  <intent-filter>
      <action android:name="android.intent.action.SHOW_BRIGHTNESS_DIALOG" />
      <category android:name="android.intent.category.DEFAULT" />
  </intent-filter>
</activity>
```

### 2.2.1 BrightnessDialog

BrightnessDialog(后简述为BD)的功能较简单,在创建的时候初始化了BrightnessController:

```java
//BrightnessDialog
@Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        ...//Ui initial
        final ImageView icon = (ImageView) findViewById(R.id.brightness_icon);
        final ToggleSlider slider = (ToggleSlider) findViewById(R.id.brightness_slider);
        mBrightnessController = new BrightnessController(this, icon, slider);//BC与ToggleSlider绑定起来。
    }

```
并在onStart，onStop分别调用如下方法，注册相应的回调函数。

```java
mBrightnessController.registerCallbacks();
mBrightnessController.unregisterCallbacks();
```

### 2.2.2 BrightnessController && BrightnessObserver 

BrightnessController正如其名(后简述为BC)，是用于控制亮度的核心，它在UI(BD)创建的时候被new。BC在创建的时候,会新建BrightnessObserver(后简述为BO),并在上述BD调用registerCallbacks,unregisterCallbacks中，分别调用startObserving以及stopObserving,用以检测系统亮度属性的变化。此后有两种方式改变亮度：

1. 通过直接拉动ToggleSlider改变亮度值。
2. 通过修改系统亮度属性改变亮度值。

由于BC继承了ToggleSlider.Listener的接口，方法1在用户拉动度条的同时，ToggleSlider会调用onChanged回调方法，由此会调用到BC的实现：

```java
//BrightnessController
@Override
public void onChanged(ToggleSlider view, boolean tracking, boolean automatic, int value,
        boolean stopTracking) {
    updateIcon(mAutomatic);
    if (mExternalChange) return;

    if (!mAutomatic) {
        final int val = value + mMinimumBacklight;
        ....
        setBrightness(val);//设置亮度
        if (!tracking) {
            //将该值存储到数据库中
            AsyncTask.execute(new Runnable() {
                    public void run() {
                        Settings.System.putIntForUser(mContext.getContentResolver(),
                                Settings.System.SCREEN_BRIGHTNESS, val,
                                UserHandle.USER_CURRENT);
                    }
                });
        }
    } else {
        //自动调节亮度，暂不分析
    }

    for (BrightnessStateChangeCallback cb : mChangeCallbacks) {
        cb.onBrightnessLevelChanged();
    }
}

```

方法2如果修改系统属性，由于BO监听了亮度有关的值，当发生改变时，会通过其BO的onChange方法进行反馈:

```java
//BrightnessObserver
public void startObserving() {
            final ContentResolver cr = mContext.getContentResolver();
            cr.unregisterContentObserver(this);
            cr.registerContentObserver(
                    BRIGHTNESS_MODE_URI,
                    false, this, UserHandle.USER_ALL);
            cr.registerContentObserver(
                    BRIGHTNESS_URI,
                    false, this, UserHandle.USER_ALL);
            cr.registerContentObserver(
                    BRIGHTNESS_ADJ_URI,
                    false, this, UserHandle.USER_ALL);
        }
...

@Override
public void onChange(boolean selfChange, Uri uri) {
    if (selfChange) return;
    try {
        mExternalChange = true;
        if (BRIGHTNESS_MODE_URI.equals(uri)) {
            updateMode();//修改亮度模式
            updateSlider();//一旦发生改变，updateSlider通过获取亮度的修改值，并反馈到进度条中
        } else if (BRIGHTNESS_URI.equals(uri) && !mAutomatic) {
            updateSlider();
        } else if (BRIGHTNESS_ADJ_URI.equals(uri) && mAutomatic) {
            updateSlider();
        } else {
            updateMode();
            updateSlider();
        }
        for (BrightnessStateChangeCallback cb : mChangeCallbacks) {
            cb.onBrightnessLevelChanged();
        }
    } finally {
        mExternalChange = false;
    }
}
```

至此，BrightnessDialog的分析告一段落,接下来可以分析setBrightness的流程。

# 3.Brightness && PowermanagerService

## 3.1 IPowerManager的Binder设计
- frameworks/base/core/java/android/os/IPowerManager.aidl

Brightness将首先与PMS发生联系，其流程图调用如下,其中由左至右，分别为IPowerManager.stub.proxy, IPowerManager.stub以及PMS

![](/img/bill/in-posts/2018-10-16/5.png)


可追溯到BC的setBrightness方法,开篇即通过经典的IPowerManager.Stub(服务端)的asInterface方法获取proxy端，以后需要调用PMS服务时，即通过proxy端通过binder与服务端进行进程间通信。

```java
//BrightnessController
private final IPowerManager mPower;
mPower = IPowerManager.Stub.asInterface(ServiceManager.getService("power"));

private void setBrightness(int brightness) {
    try {
        mPower.setTemporaryScreenBrightnessSettingOverride(brightness);
    } catch (RemoteException ex) {
    }
}
```

感兴趣的还可以找到其IPowerManager.aidl以及编译出来的IPowerManager来对比:

```java
//IPowerManager.aidl
interface IPowerManager
{
void setTemporaryScreenBrightnessSettingOverride(int brightness);
}
```

通过编译后，在out下生成对应的IPowerManager.java

```java
//out/target/common/obj/JAVA_LIBRARIES/framework_intermediates/src/core/java/android/os/IPowerManager.java

//asInterface
public static android.os.IPowerManager asInterface(android.os.IBinder obj)
{
    if ((obj==null)) {
        return null;
    }
    android.os.IInterface iin = obj.queryLocalInterface(DESCRIPTOR);
    if (((iin!=null)&&(iin instanceof android.os.IPowerManager))) {
        return ((android.os.IPowerManager)iin);
    }
    //返回的是Stub内部类Proxy代理端
    return new android.os.IPowerManager.Stub.Proxy(obj);
}
...

private static class Proxy implements android.os.IPowerManager
{
private android.os.IBinder mRemote;
Proxy(android.os.IBinder remote)
{
mRemote = remote;
...
}
```

其中Proxy的参数obj对应mRemote,指向的是服务端的对象,例如本例中调用setTemporaryScreenBrightnessSettingOverride时，生成对应的proxy方法为：

```java
//IPowerManager.Stub.Proxy
@Override public void setTemporaryScreenBrightnessSettingOverride(int brightness) throws android.os.RemoteException
{
    android.os.Parcel _data = android.os.Parcel.obtain();
    android.os.Parcel _reply = android.os.Parcel.obtain();
    try {
        _data.writeInterfaceToken(DESCRIPTOR);
        _data.writeInt(brightness);
        mRemote.transact(Stub.TRANSACTION_setTemporaryScreenBrightnessSettingOverride, _data, _reply, 0);
        _reply.readException();
    }
    finally {
        _reply.recycle();
        _data.recycle();
    }
}
```

通过aid生成的proxy方法基本都是相同的，其中`_data`,`_reply`均从Parcel池中获取，`_data`都要首先写入一个DESCRIPTOR,一般是包名，再顺序把输入参数写入,最终调用核心部分mRemote的方法transact,其实即服务端的方法。一般每个方法都对应一个int值，其定义在Stub中如下:

```java
//IPowerManager.Stub
static final int TRANSACTION_acquireWakeLock = (android.os.IBinder.FIRST_CALL_TRANSACTION + 0);
static final int TRANSACTION_acquireWakeLockWithUid = (android.os.IBinder.FIRST_CALL_TRANSACTION + 1);
....
static final int TRANSACTION_setTemporaryScreenBrightnessSettingOverride = (android.os.IBinder.FIRST_CALL_TRANSACTION + 23);
```

通过这些数值，proxy端和服务端就可以在transact的时候分清到底需要调用什么方法。再经过一系列从java到Native，到驱动，最后到服务进程中的onTransact方法,用户只需要在子类实现onTransact即可，父类已经通过aidl自动生成了:

```java
//IPowerManager.Stub onTransact()
@Override public boolean onTransact(int code, android.os.Parcel data, android.os.Parcel reply, int flags) throws android.os.RemoteException
{
...
case TRANSACTION_setTemporaryScreenBrightnessSettingOverride:
{
    data.enforceInterface(DESCRIPTOR);
    int _arg0;
    _arg0 = data.readInt();
    this.setTemporaryScreenBrightnessSettingOverride(_arg0);//子类需要实现该方法
    reply.writeNoException();
    return true;
}
...
}
```

而其子类正是之前提及的BinderService，作为PMS的内部类，最终调用到PMS的方法:

```java
    private void setTemporaryScreenBrightnessSettingOverrideInternal(int brightness);
```


## 3.2 PMS的亮度控制

PMS的调用流程图如下：

![](/img/bill/in-posts/2018-10-16/6.png)

让我有疑问的是，为什么对于亮度的调节需要经过PMS的控制，如果直接经过DMS不是方便得多么？而在updatePowerStateLocked似乎解答了这个问题,其基本实现如下几个步骤:

1. Phase 0: Basic state updates.
2. Phase 1: Update wakefulness.
3. Phase 2: Update display power state.
4. Phase 3: Update dream state (depends on display ready signal).
5. Phase 4: Send notifications, if needed.
6. Phase 5: Update suspend blocker.

其中Phase 2的目的即调用DMS来调节亮度，而除了亮度调节，还需要先判断Battery的状态，系统是否休眠，是否处于屏保模式等内容,都需要PMS进行处理,并最终调用到updateDisplayPowerStateLocked方法。


```java
//PowerManagerService
private boolean updateDisplayPowerStateLocked(int dirty) {
        final boolean oldDisplayReady = mDisplayReady;
        if ((dirty & (DIRTY_WAKE_LOCKS | DIRTY_USER_ACTIVITY | DIRTY_WAKEFULNESS
                | DIRTY_ACTUAL_DISPLAY_POWER_STATE_UPDATED | DIRTY_BOOT_COMPLETED
                | DIRTY_SETTINGS | DIRTY_SCREEN_BRIGHTNESS_BOOST)) != 0) {
            //获取显示策略
            mDisplayPowerRequest.policy = getDesiredScreenPolicyLocked();

            // Determine appropriate screen brightness and auto-brightness adjustments.
            boolean brightnessSetByUser = true;
            int screenBrightness = mScreenBrightnessSettingDefault;
            boolean autoBrightness = (mScreenBrightnessModeSetting ==
                    Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC);
            if (isValidBrightness(mScreenBrightnessOverrideFromWindowManager)) {
                screenBrightness = mScreenBrightnessOverrideFromWindowManager;
                autoBrightness = false;
                brightnessSetByUser = false;
            } else if (isValidBrightness(mTemporaryScreenBrightnessSettingOverride)) {
                screenBrightness = mTemporaryScreenBrightnessSettingOverride;
            } else if (isValidBrightness(mScreenBrightnessSetting)) {
                screenBrightness = mScreenBrightnessSetting;
            }
            if (autoBrightness) {
                //自动调节亮度相关
            }
            screenBrightness = Math.max(Math.min(screenBrightness,
                    mScreenBrightnessSettingMaximum), mScreenBrightnessSettingMinimum);
            ....
            // Update display power request.
            mDisplayPowerRequest.screenBrightness = screenBrightness;
            ...
            mDisplayPowerRequest.brightnessSetByUser = brightnessSetByUser;
            mDisplayPowerRequest.useAutoBrightness = autoBrightness;
            mDisplayPowerRequest.useProximitySensor = shouldUseProximitySensorLocked();
            mDisplayPowerRequest.lowPowerMode = mLowPowerModeEnabled;
            mDisplayPowerRequest.boostScreenBrightness = mScreenBrightnessBoostInProgress;
            mDisplayPowerRequest.useTwilight = mBrightnessUseTwilight;

            if (mDisplayPowerRequest.policy == DisplayPowerRequest.POLICY_DOZE) {
                mDisplayPowerRequest.dozeScreenState = mDozeScreenStateOverrideFromDreamManager;
                if (mDisplayPowerRequest.dozeScreenState == Display.STATE_DOZE_SUSPEND
                        && (mWakeLockSummary & WAKE_LOCK_DRAW) != 0) {
                    mDisplayPowerRequest.dozeScreenState = Display.STATE_DOZE;
                }
                mDisplayPowerRequest.dozeScreenBrightness =
                        mDozeScreenBrightnessOverrideFromDreamManager;
            } else {
                mDisplayPowerRequest.dozeScreenState = Display.STATE_UNKNOWN;
                mDisplayPowerRequest.dozeScreenBrightness = PowerManager.BRIGHTNESS_DEFAULT;
            }
            //调用到mDisplayManagerInternal实现亮度调节
            mDisplayReady = mDisplayManagerInternal.requestPowerState(mDisplayPowerRequest,
                    mRequestWaitForNegativeProximity);
            mRequestWaitForNegativeProximity = false;

        }
        return mDisplayReady && !oldDisplayReady;
    }
```

以上代码可得，PMS包装了一个DisplayPowerRequest类，并将其传递给DisplayManagerInternal，而该类用以形容电源属性(Power State),诸如屏幕是否关闭，屏幕亮度的状态等。至于DisplayManagerInternal实例，则是调用了DMS的LocalServices,毕竟PMS和DMS都属于同一个进程，不需要进行Binder通信！

```
    mDisplayManagerInternal = getLocalService(DisplayManagerInternal.class);
```


## 3.3 DMS的亮度控制

DMS的流程是亮度控制的核心,分别对应的类为：

![](/img/bill/in-posts/2018-10-16/7.png)

![](/img/bill/in-posts/2018-10-16/8.png)

承接上述分析，一切的来源均来自于PMS调用了DMS的本地服务：

事实上，DMS localService在PMS调用时，调用了initPowerMangement方法:

```java
@Override
public void initPowerManagement(final DisplayPowerCallbacks callbacks, Handler handler,
        SensorManager sensorManager) {
    synchronized (mSyncRoot) {
        //新建了DisplyBlanker对象，该对象似乎只是作为一个接口类，
        //调用到DMS的方法requestGlobalDisplayStateInternal
        DisplayBlanker blanker = new DisplayBlanker() {
            @Override
            public void requestDisplayState(int state, int brightness) {
                // The order of operations is important for legacy reasons.
                if (state == Display.STATE_OFF) {
                    requestGlobalDisplayStateInternal(state, brightness);
                }

                callbacks.onDisplayStateChange(state);

                if (state != Display.STATE_OFF) {
                    requestGlobalDisplayStateInternal(state, brightness);
                }
            }
        };
        mDisplayPowerController = new DisplayPowerController(
                mContext, callbacks, handler, sensorManager, blanker);
    }
}
```

```java
//DisplayManagerService LocalService
@Override
public boolean requestPowerState(DisplayPowerRequest request,
    boolean waitForNegativeProximity) {
    return mDisplayPowerController.requestPowerState(request, waitForNegativeProximity);
}
```

而从流程图可得，DPC(DisplayPowerController)通过Handler发送消息到DisplayControllerHandler中处理。至于为什么需要使用Handler来处理，可能是该方法耗时较久，需要另外的线程去更新状态。

```java
//DisplayPowerController

private void updatePowerState() {
...

//初次需要初始化
if (mustInitialize) {
    initialize();
}

int brightness = PowerManager.BRIGHTNESS_DEFAULT;
...//忽略了大量对brightness的赋值，只关注手动赋值
if (brightness < 0) {
    brightness = clampScreenBrightness(mPowerRequest.screenBrightness);
}


if (!mPendingScreenOff) {
    if (state == Display.STATE_ON || state == Display.STATE_DOZE) {
        //设置亮度
        animateScreenBrightness(brightness,
        slowChange ? BRIGHTNESS_RAMP_RATE_SLOW : mBrightnessRampRateFast);
    } else {
        animateScreenBrightness(brightness, 0);
    }
}
...
}
```

```java
//DisplayPowerController

private void initialize() {
    ...
    mScreenBrightnessRampAnimator = new RampAnimator<DisplayPowerState>(
            mPowerState, DisplayPowerState.SCREEN_BRIGHTNESS);
    mScreenBrightnessRampAnimator.setListener(mRampAnimatorListener);
    ...
}

private void animateScreenBrightness(int target, int rate) {
   if (mScreenBrightnessRampAnimator.animateTo(target, rate)) {
       try {
           mBatteryStats.noteScreenBrightness(target);
       } catch (RemoteException ex) {
           // same process
       }
   }
```

至此ScreenBrightnessRampAnimator调用时，传入了DisplayPowerState.SCREEN_BRIGHTNESS，当调用animateTo时，将会调用到Property的setValue方法:


```java
//DisplayPowerState

public static final IntProperty<DisplayPowerState> SCREEN_BRIGHTNESS =
        new IntProperty<DisplayPowerState>("screenBrightness") {
    @Override
    public void setValue(DisplayPowerState object, int value) {
        object.setScreenBrightness(value);
    }

    @Override
    public Integer get(DisplayPowerState object) {
        return object.getScreenBrightness();
    }
};


public void setScreenBrightness(int brightness) {
    if (mScreenBrightness != brightness) {
        mScreenBrightness = brightness;
        if (mScreenState != Display.STATE_OFF) {
            mScreenReady = false;
            scheduleScreenUpdate();
        }
    }
}

```

scheduleScreenUpdate会利用Handler发送一个Runnable对象，并实现了其中的run方法,其中涉及PhotonicModulator对象,该对象在DisplyPowerState初始化时，即作为独立线程开始运行,而这个线程的日常，貌似就是等待状态的变化

```java
//DisplayPowerState
private final Runnable mScreenUpdateRunnable = new Runnable() {
   @Override
   public void run() {
       mScreenUpdatePending = false;

       int brightness = mScreenState != Display.STATE_OFF
               && mColorFadeLevel > 0f ? mScreenBrightness : 0;
       if (mPhotonicModulator.setState(mScreenState, brightness)) {
           if (DEBUG) {
               Slog.d(TAG, "Screen ready");
           }
           mScreenReady = true;
           invokeCleanListenerIfNeeded();
       } else {
           if (DEBUG) {
               Slog.d(TAG, "Screen not ready");
           }
       }
   }
;
```

```java
//PhotonicModulator
private final class PhotonicModulator extends Thread {

    public boolean setState(int state, int backlight) {
            synchronized (mLock) {
                boolean stateChanged = state != mPendingState;
                boolean backlightChanged = backlight != mPendingBacklight;
                if (stateChanged || backlightChanged) {
                    mPendingState = state;
                    //该值即亮度
                    mPendingBacklight = backlight;

                    boolean changeInProgress = mStateChangeInProgress || mBacklightChangeInProgress;
                    mStateChangeInProgress = stateChanged;
                    mBacklightChangeInProgress = backlightChanged;

                    if (!changeInProgress) {
                        //唤醒该Lock
                        mLock.notifyAll();
                    }
                }
                return !mStateChangeInProgress;
            }
        }
}

@Override
public void run() {
    for (;;) {
        // Get pending change.
        final int state;
        final boolean stateChanged;
        final int backlight;
        final boolean backlightChanged;
        //当setvalue调用后，notifyAll后，运行以下逻辑
        synchronized (mLock) {
            state = mPendingState;
            stateChanged = (state != mActualState);
            //亮度值
            backlight = mPendingBacklight;
            backlightChanged = (backlight != mActualBacklight);
            if (!stateChanged) {
                // State changed applied, notify outer class.
                postScreenUpdateThreadSafe();
                mStateChangeInProgress = false;
            }
            if (!backlightChanged) {
                mBacklightChangeInProgress = false;
            }
            if (!stateChanged && !backlightChanged) {
                try {
                    mLock.wait();
                } catch (InterruptedException ex) { }
                continue;
            }
            mActualState = state;
            mActualBacklight = backlight;
        }
        //设置亮度,调用到DMS的方法
        mBlanker.requestDisplayState(state, backlight);
    }
} 
```

如此反反复复，最终总算回到DMS中了，最终DMS会遍历检查所有DisplayDevice，并将可用的加入workQueue中。并调用每个显示设备的requestDisplayStateLocked。

```java
//DisplayManagerService
private void applyGlobalDisplayStateLocked(List<Runnable> workQueue) {
    final int count = mDisplayDevices.size();
    for (int i = 0; i < count; i++) {
        DisplayDevice device = mDisplayDevices.get(i);
        Runnable runnable = updateDisplayStateLocked(device);
        if (runnable != null) {
            workQueue.add(runnable);
        }
    }
}
```

每个显示设备到最后，会借助到LightImpl的方法，setBrightness来实现亮度的调节。

```java
//LocalDisplayAdapter
private final class LocalDisplayDevice extends DisplayDevice {
    private final Light mBacklight;
    ...
    //LightService
    LightsManager lights = LocalServices.getService(LightsManager.class);
    mBacklight = lights.getLight(LightsManager.LIGHT_ID_BACKLIGHT);
}

private void setDisplayBrightness(int brightness) {
    try {
        mBacklight.setBrightness(brightness);
    } finally {
        ...
    }
}
```

## 3.5 LightImpl

- frameworks/base/services/core/java/com/android/server/lights/LightsService.java

回到SystemServer，在其启动时，还会调用关于Light的服务：

```java
    mSystemServiceManager.startService(LightsService.class);

```

在Light启动时，首先初始化Native层逻辑,并在onStart时，向外暴露除了接口，和SystemServer同一个进程的其他服务就可以通过LocalService去获取相关的接口。

```java
//LightsService
public LightsService(Context context) {
    super(context);
    
    mNativePointer = init_native();
    
    for (int i = 0; i < LightsManager.LIGHT_ID_COUNT; i++) {
        mLights[i] = new LightImpl(i);
    }
}

@Override
public void onStart() {
    publishLocalService(LightsManager.class, mService);
}

private final LightsManager mService = new LightsManager() {
   @Override
   //DMS可以通过getLight获取LightImpl对象
   public Light getLight(int id) {
       if (id < LIGHT_ID_COUNT) {
           return mLights[id];
       } else {
           return null;
       }
   }
};
```

至此，当DMS调用mBacklight.setBrightness(brightness)设置亮度时，将会调用如下方法：

```java
LightsService LightImpl

@Override
public void setBrightness(int brightness, int brightnessMode) {
    synchronized (this) {
        //将亮度转化为RGB
        int color = brightness & 0x000000ff;
        color = 0xff000000 | (color << 16) | (color << 8) | color;
        setLightLocked(color, LIGHT_FLASH_NONE, 0, 0, brightnessMode);
    }
}

private void setLightLocked(int color, int mode, int onMS, int offMS, int brightnessMode) {
    if (!mLocked && (color != mColor || mode != mMode || onMS != mOnMS || offMS != mOffMS ||
            mBrightnessMode != brightnessMode)) {
        mLastColor = mColor;
        mColor = color;
        mMode = mode;
        mOnMS = onMS;
        mOffMS = offMS;
        mLastBrightnessMode = mBrightnessMode;
        mBrightnessMode = brightnessMode;
        try {
            //调用Native层设置亮度
            setLight_native(mNativePointer, mId, color, mode, onMS, offMS, brightnessMode);
        } finally {
            ...
        }
    }
}
```

## 3.6 Lights的Native实现

- `frameworks/base/services/core/jni/com_android_server_lights_LightsService.cpp`

```c++
static void setLight_native(JNIEnv* /* env */, jobject /* clazz */, jlong ptr,
        jint light, jint colorARGB, jint flashMode, jint onMS, jint offMS, jint brightnessMode)
{
    Devices* devices = (Devices*)ptr;
    light_state_t state;

    if (light < 0 || light >= LIGHT_COUNT || devices->lights[light] == NULL) {
        return ;
    }

    uint32_t version = devices->lights[light]->common.version;

    memset(&state, 0, sizeof(light_state_t));

    if (brightnessMode == BRIGHTNESS_MODE_LOW_PERSISTENCE) {
        if (light != LIGHT_INDEX_BACKLIGHT) {
            ALOGE("Cannot set low-persistence mode for non-backlight device.");
            return;
        }
        if (version < LIGHTS_DEVICE_API_VERSION_2_0) {
            // HAL impl has not been upgraded to support this.
            return;
        }
    } else {
        // Only set non-brightness settings when not in low-persistence mode
        state.color = colorARGB;
        state.flashMode = flashMode;
        state.flashOnMS = onMS;
        state.flashOffMS = offMS;
    }

    state.brightnessMode = brightnessMode;

    {
        ALOGD_IF_SLOW(50, "Excessive delay setting light");
        //设置亮度
        devices->lights[light]->set_light(devices->lights[light], &state);
    }
}
```

分析了Native层后，也不适宜直接加入亮度调节的逻辑，需要往下分析Hal层的逻辑。


## 3.7 Lights的Hal层分析

在本地方案搜了个遍，居然没有发现`set_light`的实现，那么就可能是hal层没有提供相应的支持。搜了下其他方案，其实都有相关的实现，正可以借助其他方案，如华为，高通的实现，去适配本平台的功能。

```
//Android.mk

LOCAL_PATH:= $(call my-dir)
# HAL module implemenation stored in
# hw/<COPYPIX_HARDWARE_MODULE_ID>.<ro.board.platform>.so
include $(CLEAR_VARS)

LOCAL_SRC_FILES := lights.c
LOCAL_MODULE_RELATIVE_PATH := hw
LOCAL_SHARED_LIBRARIES := liblog
LOCAL_CFLAGS := $(common_flags) -DLOG_TAG=\"xxxxlights\"
LOCAL_MODULE := lights.xxxx//xxx为方案
LOCAL_MODULE_TAGS := optional

include $(BUILD_SHARED_LIBRARY)
```

由此可得，Hal层将会编译出light.[平台].so的库，提供给Native层。在HAL层，只需要实现`set_light_backlight`方法即可。

```c
//lights.c
static struct hw_module_methods_t lights_module_methods = {
    .open =  open_lights,
};

/*
 * The lights Module
 */
struct hw_module_t HAL_MODULE_INFO_SYM = {
    .tag = HARDWARE_MODULE_TAG,
    .version_major = 1,
    .version_minor = 0,
    .id = LIGHTS_HARDWARE_MODULE_ID,
    .name = "lights Module",
    .author = "Google, Inc.",
    .methods = &lights_module_methods,
};
```

```c
static int open_lights(const struct hw_module_t* module, char const* name,
        struct hw_device_t** device)
{
    int (*set_light)(struct light_device_t* dev,
            struct light_state_t const* state);

    if (0 == strcmp(LIGHT_ID_BACKLIGHT, name))
        set_light = set_light_backlight;
    else if (0 == strcmp(LIGHT_ID_NOTIFICATIONS, name))
        set_light = set_light_notifications;
    else
        return -EINVAL;

    pthread_once(&g_init, init_globals);

    struct light_device_t *dev = malloc(sizeof(struct light_device_t));

    if(!dev)
        return -ENOMEM;

    memset(dev, 0, sizeof(*dev));

    dev->common.tag = HARDWARE_DEVICE_TAG;
    dev->common.version = LIGHTS_DEVICE_API_VERSION_2_0;
    dev->common.module = (struct hw_module_t*)module;
    dev->common.close = (int (*)(struct hw_device_t*))close_lights;
    dev->set_light = set_light;

    *device = (struct hw_device_t*)dev;
    return 0;
}


static int
set_light_backlight(struct light_device_t* dev,
        struct light_state_t const* state)
{
    int err = 0;
    int brightness = rgb_to_brightness(state);
    if(!dev) {
        return -1;
    }
    pthread_mutex_lock(&g_lock);
    //打开相应的节点
    int dispfd = open(DISPLAY_DEV_PATH, O_RDWR);
    if(dispfd >= 0){
        //...进行显示同事的操作即可。。。 
        close(dispfd);
    }
    else{
        ...
    }
    pthread_mutex_unlock(&g_lock);
    return err;
}
```

至此，完成了亮度调节功能的实现，中间的过程其实十分复杂，但对于平台厂商，一般都在Hal层实现，以后需要实现类似的功能，可以快速跳过FrameWork的流程，只直接看Hal逻辑即可。

