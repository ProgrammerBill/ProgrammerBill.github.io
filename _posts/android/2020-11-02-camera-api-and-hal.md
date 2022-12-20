---
layout:     post
title:      "Camera API与HAL版本关系"
summary:    '"Camera API怎么和HAL层对应?"'
date:       2020-11-02 10:52:45
author:     "Bill"
header-img: "img/bill/header-posts/2020-11-02.jpg"
catalog: true
tags:
    - default
---


<!-- vim-markdown-toc GFM -->

* [1. 概述](#1-概述)
* [2. Camera API简介](#2-camera-api简介)
    * [2.1 Camera API1](#21-camera-api1)
        * [2.1.1 API1拍照须知](#211-api1拍照须知)
        * [2.1.2 API1录像须知](#212-api1录像须知)
        * [2.1.3 Camera API1公共方法](#213-camera-api1公共方法)
    * [2.2 Camera API2](#22-camera-api2)
        * [2.2.1 Camera API2须知](#221-camera-api2须知)
        * [2.2.2 Camera API2公共方法](#222-camera-api2公共方法)
    * [2.3 CameraAgent](#23-cameraagent)
* [3. API与HAL层对接](#3-api与hal层对接)
    * [3.1 HAL1](#31-hal1)
    * [3.2 HAL3](#32-hal3)
        * [3.2.1 getDevcieVersion](#321-getdevcieversion)
        * [3.2.2 makeClient](#322-makeclient)
        * [3.2.3 CameraClient](#323-cameraclient)
* [参考文献](#参考文献)

<!-- vim-markdown-toc -->

# 1. 概述

Camera应用接口分为API1/API2,HAL层分为HAL1/HAL3。本文的目的旨在分析
API1/API2如何与HAL1/HAL3对接。

代码可参考[cs.android.com](https://cs.android.com/)进行查阅。

# 2. Camera API简介

## 2.1 Camera API1

Camera API1在API Level21时已经被弃用了，新的应用推荐使用API2实现，但由于历史代码原因，很多应用仍然采用API1实现。

### 2.1.1 API1拍照须知

- 调用open(int)接口获取Camera实例。
- 调用getParameters()获取默认参数。
- 需要时，先通getParameters获取对象并使用setParameters进行修改。
- 调用setDisplayOrientation(int)保证正确的预览方向。
- 开始预览前，需要传递一个初始化后的SurfaceHolder到setPreviewDisplay(android.view.SurfaceHolder)。
- 调用startPreview()开启预览surface,且必须要先于拍照动作前完成。
- 调用takePicture()进行拍照，等待回调返回获取真实的拍照数据。
- 拍照后，预览显示会停止，为了继续拍照，需要再次调用startPreview。
- 调用stopPreview()来停止预览surface的更新。
- 调用release()去释放Camera资源，以及时让其他Camear应用使用。应用需要在Activity.onPause()调用时释放Camera，在Activity.onResume()时重新打开。

### 2.1.2 API1录像须知

- 如2.1.1所述对Camear进行初始化并开启预览。
- 调用unlock()允许多媒体进程访问Camera。
- 传递Camera实例给MediaRecorder.setCamera(Camera)，具体可参考MediaRecorder关于录像的流程。
- 当结束录像时，调用reconnect()重新获取以及重新上锁该Camera。
- 如果需要的话，重新启动预览以拍照和录像。
- 最后如2.1.1所述调用StopPreview()以及release()。

### 2.1.3 Camera API1公共方法

|返回值|方法名|描述|
|---|---|---|
|final void|addCallbackBuffer(byte[] callbackBuffer)|添加一个预分配的buffer到预览回调buffer队列(preview callback buffer queue)|
|final void	|autoFocus(Camera.AutoFocusCallback cb)|开启自对焦并注册回调函数，在对焦时调用|
|final void	|cancelAutoFocus()|取消自动对焦|
|final boolean	|enableShutterSound(boolean enabled)|启动或者禁用快门声|
|static void	|getCameraInfo(int cameraId, Camera.CameraInfo cameraInfo)|返回指定cameraId的Camera信息|
|static int	|getNumberOfCameras()|返回在本设备的摄像头数量|
|Camera.Parameters	|getParameters()|返回Camera服务的当前设定值|
|final void	lock()|重新锁定camera以防其他进程访问|
|static Camera	|open()|创建一个新的Camera对象并第一次访问后置摄像头|
|static Camera	|open(int cameraId)|创建一个新的Camera对象以访问特定的Camera|
|final void	|reconnect()|在其他进程使用完该Camera后，重新连接到Camera服务|
|final void	|release()|断开连接并释放Camera对象资源|
|void	|setAutoFocusMoveCallback(Camera.AutoFocusMoveCallback cb)|设置自动对焦时移动的回调函数，会在自动对焦开始或者停止时调用回调函数|
|final void	|setDisplayOrientation(int degrees)|设置预览时显示的顺时针方向角度|
|final void	|setErrorCallback(Camera.ErrorCallback cb)|注册当错误发生时的回调|
|final void	|setFaceDetectionListener(Camera.FaceDetectionListener listener)|注册监听人脸识别被检测到时的监听器|
|final void	|setOneShotPreviewCallback(Camera.PreviewCallback cb)|设定在下一预览帧在屏幕显示时被调用的回调|
|void	|setParameters(Camera.Parameters params)|修改当前Camera服务的设置|
|final void	|setPreviewCallback(Camera.PreviewCallback cb)|设置在每一个预览帧在屏幕上显示时被调用的回调|
|final void	|setPreviewCallbackWithBuffer(Camera.PreviewCallback cb)|设置每一个使用了addCallbackBuffer(byte[])的buffers的预览帧在屏幕上显示时被调用的回调|
|final void	|setPreviewDisplay(SurfaceHolder holder)|设置用于预览的Surface|
|final void	|setPreviewTexture(SurfaceTexture surfaceTexture)|设置用于预览的SurfaceTexture|
|final void	|setZoomChangeListener(Camera.OnZoomChangeListener listener)|注册一个监听camera驱动进行平滑的放大缩小时的监听器|
|final void	|startFaceDetection()|开启人脸识别|
|final void	|startPreview()|开启捕捉并将预览帧绘于屏幕上，即开启预览|
|final void	|startSmoothZoom(int value)|根据指定值进行平滑的放大缩小|
|final void	|stopFaceDetection()|停止人脸识别|
|final void	|stopPreview()|停止预览，如需再次启动，需要调用startPreview()|
|final void	|stopSmoothZoom()|停止平滑放大缩小|
|final void	|takePicture(Camera.ShutterCallback shutter, Camera.PictureCallback raw, Camera.PictureCallback postview, Camera.PictureCallback jpeg)|Triggers an asynchronous image capture.触发一次异步的图片捕捉|
|final void	|takePicture(Camera.ShutterCallback shutter, Camera.PictureCallback raw, Camera.PictureCallback jpeg)|和takePicture(Shutter, raw, null, jpeg)相同|
|final void	|unlock()|解锁Camera以允许其他进程进行访问|

## 2.2 Camera API2

从API Level 21起，Google推荐使用Camera2接口与相机进行交互，与API1相比，API2能够实现更为细腻的控制。

### 2.2.1 Camera API2须知

 android.hardware.camera2包提供了一个interface接口，用于多个独立的Camera设备与Android设备进行连接。Camera2将Camera设备设计成一个流水线模型(pipeline),它通过输入请求(input requests)，来拍摄单帧画面，并且每一个请求只拍摄一个图像。当处理完毕后，会对应输入请求随之输出一个拍摄结果(capture result)元数据包,称之为metadata packet以及一系列的输出图像数据。这些请求是按输入的顺序进行排列的，多个请求发出时，可能会同时处于传输中，称为in flight。考虑到Camera设备设计成一个具有多个阶段的流水线模型,当有多个请求传输时，需要严格保证帧率达到最大。
当需要遍历，访问以及打开一个有效的Camera设备，用户需要获取一个CameraManager实例。每一个Camera设备都会提供一系列的静态属性用于描述该硬件设备，可用选项以及输出参数。这些参数可以通过getCameraCharacteristics(String)接口获取并将信息保存到CameraCharacteristics对象中。
当需要开始拍照时，应用必须要首先创建一个捕获会话(capture session)，并且需要一系列的输出Surfaces提供给Camera设备，对应的方法是createCaptureSession(SessionConfiguration)。每个Surface必须要经过预先配置，比如适当的大小和格式，并且要和Camera设备对应。目标Surface能够被多个类获取，包括SurfaceView, SurfaceTexture, MediaCodec, MediaRecorder, Allocation以及 ImageReader。
一般来说，Camera的预览图像会被发送到SurfaceView或者TextureView, 为DngCreator捕获的Jpeg图片或者RAW数据能够通过支持Jpeg或者RAW Sensor格式的ImageReader获得。对于RenderScript,OpenGL Es, Native代码，Camera数据最好能够以YUV格式进行分配，而SurfaceTexture和ImageReader可以使用YUV\_420\_888格式保存。
应用此后需要创建一个CaptureRequest，通过定义拍照参数来决定Camera设备的图片质量。CaptureRequest还会列举本次拍照应当输出到的目标Surface。CameraDevice拥有一个工厂方法用以在特的情形下创建合适的Request builder。当CaptureRequest成设置后，它就能够被传到只拍一张照片或者连续拍照Capture Session中处理，两种方法都能够接受一连串的Reuqests，但连续的请求会比单个请求权限低。所以如果这两者同时发生时，单个拍照会在连续拍照之前进行处理。当处理完一个请求时，Camera设备会创建一个TotalCaptureResult对象，它包括在拍照时刻Camera设备的状态信息以及最终使用的设置。如果参数之间需要舍入或者有冲突无法避免的时候，Camera设备将发送一帧图像信息到输出Surfaces，这些行为是异步的，有时候会延迟。


### 2.2.2 Camera API2公共方法

|返回值|方法名|描述|
|---|---|---|
|CameraCharacteristics|getCameraCharacteristics(String cameraId)|访问camera设备的属性|
|String[]|getCameraIdList()|返回当前连接的camera设备id|
|`Set<Set<String>>`|getConcurrentCameraIds()|返回能同时使用的camera设备id|
|boolean|`isConcurrentSessionConfigurationSupported(Map<String, SessionConfiguration> cameraIdAndSessionConfig)`|检查提供的camera设备集合和对应的会话配置是否能够同时配置|
|void|openCamera(String cameraId, CameraDevice.StateCallback callback, Handler handler)|打开指定Id的camera设备|
|void|openCamera(String cameraId, Executor executor, CameraDevice.StateCallback callback)|打开指定Id的camera设备|
|void|registerAvailabilityCallback(Executor executor, CameraManager.AvailabilityCallback callback)|注册当Camera设备有效时的回调|
|void|registerAvailabilityCallback(CameraManager.AvailabilityCallback callback, Handler handler)|注册当Camera设备有效时的回调|
|void|registerTorchCallback(Executor executor, CameraManager.TorchCallback callback)|Register a callback to be notified about torch mode status.注册通知闪光灯模式状态的回调|
|void|registerTorchCallback(CameraManager.TorchCallback callback, Handler handler)|注册通知闪光灯模式状态的回调|
|void|setTorchMode(String cameraId, boolean enabled)|设置指定camera ID的闪光灯模式且不打开该设备|
|void	|unregisterAvailabilityCallback(CameraManager.AvailabilityCallback callback)|去除最近添加的回调，该回调不再接受连接或者断开回调|
|void	|unregisterTorchCallback(CameraManager.TorchCallback callback)|去除最近添加的闪光灯模式回调|

## 2.3 CameraAgent

一个Camera应用可以使用API1或者API2实现,为了兼容这两种实现，且以一种更简洁的方式帮助应用进行切换，Android提供了CameraAgent(Camera代理)来提供这样的实现。

```java
# frameworks/ex/camera2/portability/src/com/android/ex/camera2/portability/CameraAgentFactory.java
/*
*  CameraAgentFactory使用了简单工厂模式，通过传参选择类型
*/ 
public static synchronized CameraAgent getAndroidCameraAgent(Context context, CameraApi api) {
    api = validateApiChoice(api);

    if (api == CameraApi.API_1) {
        if (sAndroidCameraAgent == null) {
            sAndroidCameraAgent = new AndroidCameraAgentImpl();
            sAndroidCameraAgentClientCount = 1;
        } else {
            ++sAndroidCameraAgentClientCount;
        }
        return sAndroidCameraAgent;
    } else { // API_2
        if (highestSupportedApi() == CameraApi.API_1) {
            throw new UnsupportedOperationException("Camera API_2 unavailable on this device");
        }

        if (sAndroidCamera2Agent == null) {
            sAndroidCamera2Agent = new AndroidCamera2AgentImpl(context);
            sAndroidCamera2AgentClientCount = 1;
        } else {
            ++sAndroidCamera2AgentClientCount;
        }
        return sAndroidCamera2Agent;
    }
}
```

从上述代码可知，当传参CameraApi.API\_1时，使用AndroidCameraAgentImpl,否则使用API2,AndroidCamera2AgentImpl。

CameraAgent将常用的操作集成起来,通过CameraAgent以及内部类CameraAgent.CameraProxy可以发送请求和信息处理线，包括如：

CameraAgent:

- openCamera
- closeCamera
- reconnect

CameraAgent.CameraProxy:

- setPreviewTexture
- setPreviewTextureSync
- setPreviewDisplay
- startPreview
- startPreviewWithCallback
- stopPreview
- addCallBackBuffer
- cancelAutoFocus
- setDisplayOrientation
- setJpegOrientation
- enableShutterSound

CameraAgent并没有实现这些具体实现，而是交给AndroidCameraAgentImpl实现(API1对应AndroidCameraAgentImpl, API2对应AndroidCamera2AgentImpl)。每个具体实现会启动HandlerThread线程，专门用于处理这些信息。以AndroidCameraAgentImpl的openCamera为例:

```java
# frameworks/ex/camera2/portability/src/com/android/ex/camera2/portability/CameraAgent.java
/*
* CameraAgent
*/
public void openCamera(final Handler handler, final int cameraId,
                           final CameraOpenCallback callback) {
        try {
            getDispatchThread().runJob(new Runnable() {
                @Override
                public void run() {
                    //发送类型为OPEN_CAMERA的消息
                    getCameraHandler().obtainMessage(CameraActions.OPEN_CAMERA, cameraId, 0,
                            CameraOpenCallbackForward.getNewInstance(handler, callback)).sendToTarget();
                }
            });
        } catch (final RuntimeException ex) {
            getCameraExceptionHandler().onDispatchThreadException(ex);
        }
    }
    
# frameworks/ex/camera2/portability/src/com/android/ex/camera2/portability/AndroidCameraAgentImpl.java

@Override
public void handleMessage(final Message msg) {
    super.handleMessage(msg);
    ....
    int cameraAction = msg.what;
    try {
        switch (cameraAction) {
            case CameraActions.OPEN_CAMERA: {
                final CameraOpenCallback openCallback = (CameraOpenCallback) msg.obj;
                final int cameraId = msg.arg1;
                if (mCameraState.getState() != AndroidCameraStateHolder.CAMERA_UNOPENED) {
                    openCallback.onDeviceOpenedAlready(cameraId, generateHistoryString(cameraId));
                    break;
                }

                Log.i(TAG, "Opening camera " + cameraId + " with camera1 API");
                //使用Camera API1的方式打开camera
                mCamera = android.hardware.Camera.open(cameraId);
                if (mCamera != null) {
                    mCameraId = cameraId;
                    mParameterCache = new ParametersCache(mCamera);

                    mCharacteristics = AndroidCameraDeviceInfo.create().getCharacteristics(cameraId);
                    mCapabilities = new AndroidCameraCapabilities(
                            mParameterCache.getBlocking());

                    mCamera.setErrorCallback(this);
                    mCameraState.setState(AndroidCameraStateHolder.CAMERA_IDLE);
                    if (openCallback != null) {
                        CameraProxy cameraProxy = new AndroidCameraProxyImpl(
                                mAgent, cameraId, mCamera, mCharacteristics, mCapabilities);
                        openCallback.onCameraOpened(cameraProxy);
                    }
                } else {
                    if (openCallback != null) {
                        openCallback.onDeviceOpenFailure(cameraId, generateHistoryString(cameraId));
                    }
                }
                break;
            }
        ...
```

```
# frameworks/ex/camera2/portability/src/com/android/ex/camera2/portability/AndroidCamera2AgentImpl.java
@Override
public void handleMessage(final Message msg) {
    super.handleMessage(msg);
    Log.v(TAG, "handleMessage - action = '" + CameraActions.stringify(msg.what) + "'");
    int cameraAction = msg.what;
    try {
        switch (cameraAction) {
            case CameraActions.OPEN_CAMERA:
            case CameraActions.RECONNECT: {
                CameraOpenCallback openCallback = (CameraOpenCallback) msg.obj;
                int cameraIndex = msg.arg1;

                if (mCameraState.getState() > AndroidCamera2StateHolder.CAMERA_UNOPENED) {
                    openCallback.onDeviceOpenedAlready(cameraIndex,
                            generateHistoryString(cameraIndex));
                    break;
                }

                mOpenCallback = openCallback;
                mCameraIndex = cameraIndex;
                mCameraId = mCameraDevices.get(mCameraIndex);
                Log.i(TAG, String.format("Opening camera index %d (id %s) with camera2 API",
                        cameraIndex, mCameraId));

                if (mCameraId == null) {
                    mOpenCallback.onCameraDisabled(msg.arg1);
                    break;
                }
                //使用Camera API2打开摄像头
                mCameraManager.openCamera(mCameraId, mCameraDeviceStateCallback, this);

                break;
            }

```

# 3. API与HAL层对接

## 3.1 HAL1

HAL1最开始的设计是对接API1,而后续产生的API2虽然对标HAL3，但也需要兼容HAL1。最方便的方法是将API2和API1进行一个转换来支持HAL1。以打开Camera的操作为例，API1调用HAL1示意图如下:

![API1/HAL1](/img/bill/in-posts/2020-11-02/camera_api1_hal1_open.png)


API2在使用HAL1前，进行了转换。层层调用后，最终调用到Camera API1的接口。因此只绘出转换部分:

![API2/HAL1](/img/bill/in-posts/2020-11-02/camera_api2_hal1_open.png)

## 3.2 HAL3

HAL3通过makeClient来分辨使用的是哪一套API接口，流程图如下所示:

以API1调用HAL3的流程如下:

![API1/HAL3](/img/bill/in-posts/2020-11-02/camera_api1_hal3_open.png)

以API2调用HAL3的流程如下:

![API2/HAL3](/img/bill/in-posts/2020-11-02/camera_api2_hal3_open.png)

HAL3的调用流程较为类似，应用调用打开Camera的操作，经历了Apk,CameraService以及HAL层Camera服务的流程。图中省去了进程间的Binder通信流程，可以看出,主要的几个关键点在于:

### 3.2.1 getDevcieVersion

在调用关键的makeClient前，connectHelper中调用getDeviceVersion来判断到底是使用哪一套HAL接口,关键代码如下:

```
# frameworks/av/services/camera/libcameraservice/CameraService.cpp
# inside Function ConnectHelper
    ...
    int facing = -1;
    //获取设备HAL版本
    int deviceVersion = getDeviceVersion(cameraId, /*out*/&facing);
    if (facing == -1) {
        ALOGE("%s: Unable to get camera device \"%s\"  facing", __FUNCTION__, cameraId.string());
        return STATUS_ERROR_FMT(ERROR_INVALID_OPERATION,
                "Unable to get camera device \"%s\" facing", cameraId.string());
    }

    sp<BasicClient> tmp = nullptr;
    //关键分水岭，初始化halVersion为-1
    if(!(ret = makeClient(this, cameraCb, clientPackageName, clientFeatureId,
            cameraId, api1CameraId, facing,
            clientPid, clientUid, getpid(),
            halVersion, deviceVersion, effectiveApiLevel,
            /*out*/&tmp)).isOk()) {
        return ret;
    }
    client = static_cast<CLIENT*>(tmp.get());
    ...
    
# getDeviceVersion

int CameraService::getDeviceVersion(const String8& cameraId, int* facing) {
    ATRACE_CALL();

    int deviceVersion = 0;

    status_t res;
    hardware::hidl_version maxVersion{0,0};
    //获取HAL支持最高版本
    res = mCameraProviderManager->getHighestSupportedVersion(cameraId.string(),
            &maxVersion);
    if (res != OK) return -1;
    deviceVersion = HARDWARE_DEVICE_API_VERSION(maxVersion.get_major(), maxVersion.get_minor());

    hardware::CameraInfo info;
    if (facing) {
        res = mCameraProviderManager->getCameraInfo(cameraId.string(), &info);
        if (res != OK) return -1;
        *facing = info.facing;
    }

    return deviceVersion;
}
```

### 3.2.2 makeClient

deviceVersion与API的版将决定Client的类型。HAL1与API1的配置会新建CameraClient(HAL1和API2组合实质进行了转换，只走HAL1+API1)，HAL3与API1的组合会新建Camera2Client，HAL3和API2的组合则新建CameraDeviceClient。

```java
Status CameraService::makeClient(const sp<CameraService>& cameraService,
        const sp<IInterface>& cameraCb, const String16& packageName,
        const std::optional<String16>& featureId, const String8& cameraId, int api1CameraId,
        int facing, int clientPid, uid_t clientUid, int servicePid, int halVersion,
        int deviceVersion, apiLevel effectiveApiLevel,
        /*out*/sp<BasicClient>* client) {
    //初始化halVersion小于0
    if (halVersion < 0 || halVersion == deviceVersion) {
        /*
        * 此处通过deviceVersion类型创建client。
        * HAL1: CameraClient
        * HAL3: Camera2Client
        */
        switch(deviceVersion) {
          case CAMERA_DEVICE_API_VERSION_1_0:
            if (effectiveApiLevel == API_1) {  // Camera1 API route
                sp<ICameraClient> tmp = static_cast<ICameraClient*>(cameraCb.get());
                *client = new CameraClient(cameraService, tmp, packageName, featureId,
                        api1CameraId, facing, clientPid, clientUid,
                        getpid());
            } else { // Camera2 API route
                ALOGW("Camera using old HAL version: %d", deviceVersion);
                return STATUS_ERROR_FMT(ERROR_DEPRECATED_HAL,
                        "Camera device \"%s\" HAL version %d does not support camera2 API",
                        cameraId.string(), deviceVersion);
            }
            break;
          case CAMERA_DEVICE_API_VERSION_3_0:
          case CAMERA_DEVICE_API_VERSION_3_1:
          case CAMERA_DEVICE_API_VERSION_3_2:
          case CAMERA_DEVICE_API_VERSION_3_3:
          case CAMERA_DEVICE_API_VERSION_3_4:
          case CAMERA_DEVICE_API_VERSION_3_5:
          case CAMERA_DEVICE_API_VERSION_3_6:
            if (effectiveApiLevel == API_1) { // Camera1 API route
                sp<ICameraClient> tmp = static_cast<ICameraClient*>(cameraCb.get());
                *client = new Camera2Client(cameraService, tmp, packageName, featureId,
                        cameraId, api1CameraId,
                        facing, clientPid, clientUid,
                        servicePid);
            } else { // Camera2 API route
                sp<hardware::camera2::ICameraDeviceCallbacks> tmp =
                        static_cast<hardware::camera2::ICameraDeviceCallbacks*>(cameraCb.get());
                *client = new CameraDeviceClient(cameraService, tmp, packageName, featureId,
                        cameraId, facing, clientPid, clientUid, servicePid);
            }
            break;
          default:
            // Should not be reachable
            ALOGE("Unknown camera device HAL version: %d", deviceVersion);
            return STATUS_ERROR_FMT(ERROR_INVALID_OPERATION,
                    "Camera device \"%s\" has unknown HAL version %d",
                    cameraId.string(), deviceVersion);
        }
    } else {
        // A particular HAL version is requested by caller. Create CameraClient
        // based on the requested HAL version.
        if (deviceVersion > CAMERA_DEVICE_API_VERSION_1_0 &&
            halVersion == CAMERA_DEVICE_API_VERSION_1_0) {
            // Only support higher HAL version device opened as HAL1.0 device.
            sp<ICameraClient> tmp = static_cast<ICameraClient*>(cameraCb.get());
            *client = new CameraClient(cameraService, tmp, packageName, featureId,
                    api1CameraId, facing, clientPid, clientUid,
                    servicePid);
        } else {
            // Other combinations (e.g. HAL3.x open as HAL2.x) are not supported yet.
            ALOGE("Invalid camera HAL version %x: HAL %x device can only be"
                    " opened as HAL %x device", halVersion, deviceVersion,
                    CAMERA_DEVICE_API_VERSION_1_0);
            return STATUS_ERROR_FMT(ERROR_ILLEGAL_ARGUMENT,
                    "Camera device \"%s\" (HAL version %d) cannot be opened as HAL version %d",
                    cameraId.string(), deviceVersion, halVersion);
        }
    }
    return Status::ok();
}
```

### 3.2.3 CameraClient

由上述可得，HAL1对应CameraClient，HAL3对应Camera2Client或者CameraDeviceClient。Camera2Client以及CameraDeviceClient都继承了Camear2ClientBase，而这个父类使用的是Camera3Device，表明这是HAL3。Camera3Device实现了一个内部类名为HalInterface，与HAL层的交互均依靠该类实现。

```

template <typename TClientBase>
Camera2ClientBase<TClientBase>::Camera2ClientBase(
        const sp<CameraService>& cameraService,
        const sp<TCamCallbacks>& remoteCallback,
        const String16& clientPackageName,
        const std::optional<String16>& clientFeatureId,
        const String8& cameraId,
        int api1CameraId,
        int cameraFacing,
        int clientPid,
        uid_t clientUid,
        int servicePid):
        TClientBase(cameraService, remoteCallback, clientPackageName, clientFeatureId,
                cameraId, api1CameraId, cameraFacing, clientPid, clientUid, servicePid),
        mSharedCameraCallbacks(remoteCallback),
        mDeviceVersion(cameraService->getDeviceVersion(TClientBase::mCameraIdStr)),
        mDevice(new Camera3Device(cameraId)),//此处使用Camera3Device。
        mDeviceActive(false), mApi1CameraId(api1CameraId)
{
    ALOGI("Camera %s: Opened. Client: %s (PID %d, UID %d)", cameraId.string(),
            String8(clientPackageName).string(), clientPid, clientUid);

    mInitialClientPid = clientPid;
    LOG_ALWAYS_FATAL_IF(mDevice == 0, "Device should never be NULL here.");
}

```

而HAL1的CameraClient则是通过CameraHardwareInterface去实现的。

```
# frameworks/av/services/camera/libcameraservice/api1/CameraClient.cpp
status_t CameraClient::initialize(sp<CameraProviderManager> manager,
        const String8& /*monitorTags*/) {
    int callingPid = CameraThreadState::getCallingPid();
    status_t res;

    LOG1("CameraClient::initialize E (pid %d, id %d)", callingPid, mCameraId);

    // Verify ops permissions
    res = startCameraOps();
    if (res != OK) {
        return res;
    }

    char camera_device_name[10];
    snprintf(camera_device_name, sizeof(camera_device_name), "%d", mCameraId);
    //新建CamearHardwareInterface，其实现可参考hardware/interfaces/camera/device/1.0/default/CameraDevice.cpp
    mHardware = new CameraHardwareInterface(camera_device_name);
    res = mHardware->initialize(manager);
    if (res != OK) {
        ALOGE("%s: Camera %d: unable to initialize device: %s (%d)",
                __FUNCTION__, mCameraId, strerror(-res), res);
        mHardware.clear();
        return res;
    }

    mHardware->setCallbacks(notifyCallback,
            dataCallback,
            dataCallbackTimestamp,
            handleCallbackTimestampBatch,
            (void *)(uintptr_t)mCameraId);

    // Enable zoom, error, focus, and metadata messages by default
    enableMsgType(CAMERA_MSG_ERROR | CAMERA_MSG_ZOOM | CAMERA_MSG_FOCUS |
                  CAMERA_MSG_PREVIEW_METADATA | CAMERA_MSG_FOCUS_MOVE);

    LOG1("CameraClient::initialize X (pid %d, id %d)", callingPid, mCameraId);
    return OK;
}
```


# 参考文献

- [Camera API官网参考](https://developer.android.com/reference/android/hardware/Camera)
- [android camera API1调用camera HAL3流程学习总结](https://blog.csdn.net/zhuyong006/article/details/102480557)
