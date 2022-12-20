---
layout:     post
title:      "Android P编译简析[二]"
summary:   '"build system"'
date:       2019-04-05 17:44:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-01-17.jpg"
catalog: true
tags:
    - android
    - build
---

<!-- vim-markdown-toc GFM -->

* [2. 固件编译流程](#2-固件编译流程)
	* [2.1 DroidCore](#21-droidcore)
	* [2.2 systemimage](#22-systemimage)
	* [2.3 boot.img](#23-bootimg)
	* [2.4 files](#24-files)
	* [2.5 vendorimage](#25-vendorimage)
	* [2.6 import-products](#26-import-products)

<!-- vim-markdown-toc -->

# 2. 固件编译流程

## 2.1 DroidCore

编译固件首先从DroidCore根节点出发，分别包含了:

- systemimage
- bootimage
- recoveryimage
- dataimage
- cacheimage
- vendorimage
- .....

```makefile
.PHONY: droidcore
droidcore: files \
	systemimage \
	$(INSTALLED_BOOTIMAGE_TARGET) \
	$(INSTALLED_RECOVERYIMAGE_TARGET) \
	$(INSTALLED_VBMETAIMAGE_TARGET) \
	$(INSTALLED_USERDATAIMAGE_TARGET) \
	$(INSTALLED_CACHEIMAGE_TARGET) \
	$(INSTALLED_BPTIMAGE_TARGET) \
	$(INSTALLED_VENDORIMAGE_TARGET) \
	$(INSTALLED_PRODUCTIMAGE_TARGET) \
	$(INSTALLED_SYSTEMOTHERIMAGE_TARGET) \
	$(INSTALLED_FILES_FILE) \
	$(INSTALLED_FILES_FILE_VENDOR) \
	$(INSTALLED_FILES_FILE_PRODUCT) \
	$(INSTALLED_FILES_FILE_SYSTEMOTHER) \
	soong_docs
```


## 2.2 systemimage

systemimage即生成的system.img，Android中Framework将编译在该镜像中。systemimage首先依赖于`INSTALLED_SYSTEMIMAGE`:

```makefile
.PHONY: systemimage
systemimage:

systemimage: $(INSTALLED_SYSTEMIMAGE)
```


`INSTALLED_SYSTEMIMAGE`依赖于`BUILT_SYSTEMIMAGE`以及 `RECOVERY_FROM_BOOT_PATCH`。其中后者为生成recovery.patch文件(recovery与boot都包含了ramdisk以及kernel，因此可以通过差分形式生成recovery.img)

```makefile
INSTALLED_SYSTEMIMAGE := $(PRODUCT_OUT)/system.img

$(INSTALLED_SYSTEMIMAGE): $(BUILT_SYSTEMIMAGE) $(RECOVERY_FROM_BOOT_PATCH)
	@echo "Install system fs image: $@"
	$(copy-file-to-target)
	$(hide) $(call assert-max-image-size,$@ $(RECOVERY_FROM_BOOT_PATCH),$(BOARD_SYSTEMIMAGE_PARTITION_SIZE))
```


当源文件发生改动时，将首先触发copy-file-to-target,该方法将会先创建system.img的目录，并删除编译目标(system.img),最后将"$<"（第一个依赖目标）拷贝为编译目标，如此看来`BUILT_SYSTEMIMAGE`也是system.img文件。

```makefile
define copy-file-to-target
@mkdir -p $(dir $@)
$(hide) rm -f $@
$(hide) cp "$<" "$@"
endef
```

等拷贝完毕后，依赖文件之前还有`RECOVERY_FROM_BOOT_PATCH`，发现并没有编译进system.img中，而是作为调用assert-max-image-size的输入参数。$1即`$@(INSTALLED_SYSTEMIMAGE)`与`RECOVERY_FROM_BOOT_PATCH`，$2即为一般在BoardConfig.mk中定义的`BOARD_SYSTEMIMAGE_PARTITION_SIZE`。

```makefile
# $(1): The file(s) to check (often $@)
# $(2): The partition size.
define assert-max-image-size
$(if $(2), \
  size=$$(for i in $(1); do $(call get-file-size,$$i); echo +; done; echo 0); \
  total=$$(( $$( echo "$$size" ) )); \
  printname=$$(echo -n "$(1)" | tr " " +); \
  maxsize=$$(($(2))); \
  if [ "$$total" -gt "$$maxsize" ]; then \
    echo "error: $$printname too large ($$total > $$maxsize)"; \
    false; \
  elif [ "$$total" -gt $$((maxsize - 32768)) ]; then \
    echo "WARNING: $$printname approaching size limit ($$total now; limit $$maxsize)"; \
  fi \
 , \
  true \
 )
endef
```

函数方法即检查目标文件的大小与最大值进行对比，超过最大值则报错终止，如果在区间(maxsize，32768-maxsize)之间，则温馨的给出提示。

`BUILT_SYSTEMIMAGE`符合前文提到的，是system.img镜像文件，`systemimage_intermediates`为编译中途生成的中间文件，调用intermediates-dir-for就是为了在PACKING文件家中找到systemimage相关的目录。

```makefile
systemimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,systemimage)
BUILT_SYSTEMIMAGE := $(systemimage_intermediates)/system.img
```

`BUILT_SYSTEMIMAGE`依赖于`FULL_SYSTEMIMAGE_DEPS`，`INSTALLED_FILES_FILE`以及`BUILD_IMAGE_SRCS`，而触发的规则也很直接`build-systemimage-target`,就是创建一个systemimage，由此可以分步学习其中的内容。

```makefile
$(BUILT_SYSTEMIMAGE): $(FULL_SYSTEMIMAGE_DEPS) $(INSTALLED_FILES_FILE) $(BUILD_IMAGE_SRCS)
	$(call build-systemimage-target,$@)
```

`FULL_SYSTEMIMAGE_DEPS`包括了`INTERNAL_SYSTEMIMAGE_FILES`以及`INTERNAL_USERIMAGES_DEPS`。看命名方式，似乎时内置类型的文件。除外加入asan.tar.bz2存在的话，也会将该文件纳入到目标当中。

```makefile
FULL_SYSTEMIMAGE_DEPS := $(INTERNAL_SYSTEMIMAGE_FILES) $(INTERNAL_USERIMAGES_DEPS)

# ASAN libraries in the system image - add dependency.
ASAN_IN_SYSTEM_INSTALLED := $(TARGET_OUT)/asan.tar.bz2
ifneq (,$(SANITIZE_TARGET))
  ifeq (true,$(SANITIZE_TARGET_SYSTEM))
    FULL_SYSTEMIMAGE_DEPS += $(ASAN_IN_SYSTEM_INSTALLED)
  endif
endif

```

asan为Address Santizer, 按照官网介绍是一个快速的内存检查器，能够检查包括:

- Out-of-bounds accesses to heap, stack and globals
- Use-after-free
- Use-after-return (runtime flag ASAN_OPTIONS=detect_stack_use_after_return=1)
- Use-after-scope (clang flag -fsanitize-address-use-after-scope)
- Double-free, invalid free
- Memory leaks (experimental)

---------------------------------------

`INTERNAL_SYSTEMIMAGE_FILES`包括了`ALL_GENERATED_SOURCES`, `ALL_DEFAULT_INSTALLED_MODULES`, `PDK_FUSION_SYSIMG_FILES`,`RECOVERY_RESOURCE_ZIP`,`PDK_FUSION_SYMLINK_STAMP`中，匹配在`TARGET_OUT`目录下的内容。

```makefile
INTERNAL_SYSTEMIMAGE_FILES := $(filter $(TARGET_OUT)/%, \
    $(ALL_GENERATED_SOURCES) \
    $(ALL_DEFAULT_INSTALLED_MODULES) \
    $(PDK_FUSION_SYSIMG_FILES) \
    $(RECOVERY_RESOURCE_ZIP)) \
    $(PDK_FUSION_SYMLINK_STAMP)
```


关于变量`ALL_GENERATED_SOURCS`,在definitions.mk定义是所有通过工具生成的文件。在生成binary文件时，如果单独Android.mk中定义了`LOCAL_GENERATED_SOURCES`,该定义的文件将会被拷贝到intermediates目录下，并最终加入到`ALL_GENERATED_SOURCES`。查阅Android.mk手册中明确指明了,`LOCAL_GENERATED_SOURCES`中的内容，将会在模块编译完成后自动生成并链接。

```makefile
# definitions.mk

# Full path to all files that are made by some tool
ALL_GENERATED_SOURCES:=
```

```makefile
# binary.mk
my_generated_sources := $(LOCAL_GENERATED_SOURCES)
....
$(my_generated_sources): PRIVATE_MODULE := $(my_register_name)

my_gen_sources_copy := $(patsubst $(generated_sources_dir)/%,$(intermediates)/%,$(filter $(generated_sources_dir)/%,$(my_generated_sources)))

$(my_gen_sources_copy): $(intermediates)/% : $(generated_sources_dir)/%
	@echo "Copy: $@"
	$(copy-file-to-target)

my_generated_sources := $(patsubst $(generated_sources_dir)/%,$(intermediates)/%,$(my_generated_sources))

# Generated sources that will actually produce object files.
# Other files (like headers) are allowed in LOCAL_GENERATED_SOURCES,
# since other compiled sources may depend on them, and we set up
# the dependencies.
my_gen_src_files := $(filter %.c %$(LOCAL_CPP_EXTENSION) %.S %.s,$(my_generated_sources))

ALL_GENERATED_SOURCES += $(my_generated_sources)
```

这里并没有看到`LOCAL_GENERATED_SOURCES`是如何编译的，但其实需要开发人员在定义自动生成源文件的时候规划好，并最终调用方法transform-generated-source生成目标。AndroidO之后支持了HIDL，而在生成hidl文件时，也常如下方式实现:

```makefile
#demo
GEN := $(intermediates)/xxx.java
$(GEN): $(HIDL)
$(GEN): PRIVATE_HIDL := $(HIDL)
$(GEN): PRIVATE_DEPS := $(LOCAL_PATH)/types.hal
$(GEN): PRIVATE_OUTPUT_DIR := $(intermediates)
$(GEN): PRIVATE_CUSTOM_TOOL = \
        $(PRIVATE_HIDL) -o $(PRIVATE_OUTPUT_DIR) \
        -Ljava \
        -randroid.hidl:system/libhidl/transport \
        ...

$(GEN): $(LOCAL_PATH)/types.hal
	$(transform-generated-source)
LOCAL_GENERATED_SOURCES += $(GEN)
```

transform-generated-source中可看出实际上是运行了`PRIVATE_CUSTOM_TOOL`命令，即只要实现`PRIVATE_CUSTOM_TOOL`即可。

```makefile
define transform-generated-source
@echo "$($(PRIVATE_PREFIX)DISPLAY) Generated: $(PRIVATE_MODULE) <= $<"
@mkdir -p $(dir $@)
$(hide) $(PRIVATE_CUSTOM_TOOL)
endef
```
---------------------------------------

`ALL_DEFAULT_INSTALLED_MODULES`涉及的内容巨多,在main.mk中对该变量进行了多次的增添，`ALL_DEFAULT_INSTALLED_MODULES`被赋值为`module_to_install`.

```makefile
# build/make/core/Makefile contains extra stuff that we don't want to pollute this
# top-level makefile with.  It expects that ALL_DEFAULT_INSTALLED_MODULES
# contains everything that's built during the current make, but it also further
# extends ALL_DEFAULT_INSTALLED_MODULES.
ALL_DEFAULT_INSTALLED_MODULES := $(modules_to_install)
include $(BUILD_SYSTEM)/Makefile
modules_to_install := $(sort $(ALL_DEFAULT_INSTALLED_MODULES))
ALL_DEFAULT_INSTALLED_MODULES :=
```

其中`product_MODULES`中保存了`PRODUCT_PACKAGES`，即如果需要编译模块时，都需要增添`PRODUCT_PACKAGES += xxx`。并调用方法module-installed-files，遍历`product_MODULES`并创建了形式如`"ALL_MODULES.$(module).INSTALLED"`的变量，中间为`PRODUCT_PACKAGES`名.所以可以简单认为`product_MODULES`保存的是需要编译的模块。

```makefile
define module-installed-files
$(foreach module,$(1),$(ALL_MODULES.$(module).INSTALLED))
endef

product_MODULES := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES)
...
product_FILES := $(call module-installed-files, $(product_MODULES))

modules_to_install := $(sort \
    $(ALL_DEFAULT_INSTALLED_MODULES) \
    $(product_FILES) \
    $(foreach tag,$(tags_to_install),$($(tag)_MODULES)) \
    $(CUSTOM_MODULES) \
  )
```

至于`tags_to_install`,假如选择的是userdebug，则`tags_to_install`为debug,假如为eng，则为debug以及eng。`$(foreach tag,$(tags_to_install),$($(tag)_MODULES))`即编译相关tag的模块，如为eng时，则为`eng_MODULES`以及`debug_MODULES`。而它们的内容又通过get-tagged-modules方法进行填充。

```makefile
eng_MODULES := $(sort \
        $(call get-tagged-modules,eng) \
        $(call module-installed-files, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_ENG)) \
    )
debug_MODULES := $(sort \
        $(call get-tagged-modules,debug) \
        $(call module-installed-files, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_DEBUG)) \
    )
tests_MODULES := $(sort \
        $(call get-tagged-modules,tests) \
        $(call module-installed-files, $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_TESTS)) \
    )INTERNAL_SYSTEMIMAGE_FILES
```

- eng固件: `tags_to_install`: debug eng
- user固件: `tags_to_install`: null
- userdebug固件: `tags_to_install`: debug

其中`get-tagged-modules`一般只跟一个参数，即转化为调用`call modules-for-tag-list,$(1)`,以上述对eng进行处理，即从`ALL_MODULE_NAME_TAGS.eng`中遍历每个元素m，转化为`ALL_MODULS.$(m).INSTALLD`。

```makefile
define get-tagged-modules
$(filter-out \
	$(call modules-for-tag-list,$(2)), \
	    $(call modules-for-tag-list,$(1)))
endef

define modules-for-tag-list
$(sort $(foreach tag,$(1),$(foreach m,$(ALL_MODULE_NAME_TAGS.$(tag)),$(ALL_MODULES.$(m).INSTALLED))))
endef
```

module-installed-files则从`$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES_ENG)`中遍历元素module,转化为`ALL_MODULES.$(module).INSTALLD`。

```makefile
define module-installed-files
$(foreach module,$(1),$(ALL_MODULES.$(module).INSTALLED))
endef
```

总结以上看，`modules_to_install`中会包括默认安装的模块，纳入编译的模块，以及和被打上特定标签的模块。其格式均为`ALL_MODULES.$(module).INSTALLD`。如果以`PRODUCT_PACKAGES`增加模块的，最终模块将增添在`PRODUCTS.device/xxxx/abc.mk.PRODUCT_PACKAGES`中，如果是以`PRODUCT_PACKAGES_DEBUG`形式增加的，该模块将增添在`PRODUCTS.device/xxxx/abc.mk.PRODUCT_PACKAGES_DEBUG`中。如果对上述参数有疑惑的，Android也提供了打印产品变量的方法:

```makefile
make dump-products
```

假如方案目录中在/device/xxxx/abc.mk,则打印形式如下:

```makefile
PRODUCTS.device/xxxx/abc.mk.PRODUCT_NAME := $(PRODUCT_NAME)
PRODUCTS.device/xxxx/abc.mk.PRODUCT_MODULE := $(PRODUCT_MODEL)
....
PRODUCTS.device/xxxx/abc.mk.PRODUCT_PACKAGES := ....
PRODUCTS.device/xxxx/abc.mk.PRODUCT_PACKAGES_DEBUG := ....
PRODUCTS.device/xxxx/abc.mk.PRODUCT_PACKAGES_ENG := ....
PRODUCTS.device/xxxx/abc.mk.PRODUCT_PACKAGES_TESTS := ....
```

至于之前提到的 `INTERNAL_SYSTEMIMAGE_FILES`中的`$(PDK_FUSION_SYSIMG_FILES)`,`$(PDK_FUSION_SYMLINK_STAMP)`与PDK相关，可不深入解析。`RECOVERY_RESOURCE_ZIP`是在传统的非A/B升级中需要的，但本方案中由于加入了DTBO，因此`RECOVERY_RESORCE_ZIP`为空:

```makefile
ifeq (,$(filter true, $(BOARD_USES_FULL_RECOVERY_IMAGE) $(BOARD_BUILD_SYSTEM_ROOT_IMAGE) \
  $(BOARD_INCLUDE_RECOVERY_DTBO)))
# Named '.dat' so we don't attempt to use imgdiff for patching it.
RECOVERY_RESOURCE_ZIP := $(TARGET_OUT)/etc/recovery-resource.dat
else
RECOVERY_RESOURCE_ZIP :=
endif
```

------------------------------------
```makefile
FULL_SYSTEMIMAGE_DEPS := $(INTERNAL_SYSTEMIMAGE_FILES) $(INTERNAL_USERIMAGES_DEPS)
```

至此完成了`INTERNAL_SYSTEMIMAGE_FILES`的解析，但`FULL_SYSTEMIMAGE_DEPS`还依赖于`INTERNAL_USERIMAGES_DEPS`。`INTERNAL_USERIMAGES_DEPS`包括了多个制作镜像的工具，包括:

- simg2img：sparse image转化为raw iamge工具
- img2simg：raw image转化为sparse image工具
- mke2fs: 建立ext4文件系统
- e2fsck：修复文件系统
等等.

通过grep 关键字`INTERNAL_USERIMAGES_DEPS`,可以发现被多次依赖，证明需要制作image的目标，均需要依赖这些工具。

```makefile
Makefile:1823:userdataimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
Makefile:1922:$(INSTALLED_CACHEIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_CACHEIMAGE_FILES) $(BUILD_IMAGE_SRCS)
Makefile:1926:cacheimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
Makefile:1981:$(INSTALLED_SYSTEMOTHERIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_SYSTEMOTHERIMAGE_FILES) $(INSTALLED_FILES_FILE_SYSTEMOTHER)
Makefile:1986:systemotherimage-nodeps: | $(INTERNAL_USERIMAGES_DEPS)
Makefile:2030:$(INSTALLED_VENDORIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_VENDORIMAGE_FILES) $(INSTALLED_FILES_FILE_VENDOR) $(BUILD_IMAGE_SRCS) $(DEPMOD) $(BOARD_VENDOR_KERNEL_MODULES)
```

`INSTALLED_FILES_FILE`依赖之前分析的`FULL_SYSTEMIMAGE_DEPS`以及`FILESLIST`。

```makefile
FILESLIST := $(SOONG_HOST_OUT_EXECUTABLES)/fileslist
...
INSTALLED_FILES_FILE := $(PRODUCT_OUT)/installed-files.txt
$(INSTALLED_FILES_FILE): $(FULL_SYSTEMIMAGE_DEPS) $(FILESLIST)
	@echo Installed file list: $@
	@mkdir -p $(dir $@)
	@rm -f $@
	$(hide) $(FILESLIST) $(TARGET_OUT) > $(@:.txt=.json)
	$(hide) build/make/tools/fileslist_util.py -c $(@:.txt=.json) > $@
```

其中fileslist为工具，可以将指定文件夹作为输入参数，生成installed-files.json,内容如下格式,可以看到文件的SHA256以及大小。

```makefile
[
    {
    "SHA256": "e9c7be5dba070c6d1220594582ebd0bbbb6890eee69aaf8da4dda3662f96780d",
    "Name": "/system/priv-app/PrebuiltGmsCorePi/PrebuiltGmsCorePi.apk",
    "Size": 89546289
  },
  {
    "SHA256": "d3eea5a60b778a35155b197d8649878cf5eae75f86cd2b155c4431e5a9bc11aa",
    "Name": "/system/priv-app/Chrome/Chrome.apk",
    "Size": 71841115
  },
  {
    "SHA256": "888c0677e896272b3f03a2f6ed44754779ef947d0b15dcf595cade1402dd6fcd",
    "Name": "/system/app/webview/webview.apk",
    "Size": 52167534
  },
]
....
```

最后通过fileslist_util.py，生成最终的fileslist文件，其形式如下,仅包括文件大小了。

```
89546289  /system/priv-app/PrebuiltGmsCorePi/PrebuiltGmsCorePi.apk
71841115  /system/priv-app/Chrome/Chrome.apk
52167534  /system/app/webview/webview.apk
...
```

---------------------------------

```makefile
$(BUILT_SYSTEMIMAGE): $(FULL_SYSTEMIMAGE_DEPS) $(INSTALLED_FILES_FILE) $(BUILD_IMAGE_SRCS)
	$(call build-systemimage-target,$@)
```

`BUILT_SYSTEMIMAGE`最后还依赖于`BUILD_IMAGE_SRCS`,指的是build/make/tools/releasetools/下的python文件，如果做过OTA方面的工作开发者一般不会陌生，包括制作OTA包脚本(`ota_from_target_files.py`)，签名相关的脚本(`sign_target_files_apks.py`)，将targetfile生成image的脚本(`img_from_target_files.py`)等等。至此，先决条件已完成。可分析build-systemimage-target
```makefile
BUILD_IMAGE_SRCS := $(wildcard build/make/tools/releasetools/*.py)
```

build-systemimage-target是生成system.img的重要方法，其步骤如下:

```makefile
# $(1): output file
define build-systemimage-target
  @echo "Target system fs image: $(1)"
  $(call create-system-vendor-symlink)
  $(call create-system-product-symlink)
  @mkdir -p $(dir $(1)) $(systemimage_intermediates) && rm -rf $(systemimage_intermediates)/system_image_info.txt
  $(call generate-userimage-prop-dictionary, $(systemimage_intermediates)/system_image_info.txt, \
      skip_fsck=true)
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      build/make/tools/releasetools/build_image.py \
      $(TARGET_OUT) $(systemimage_intermediates)/system_image_info.txt $(1) $(TARGET_OUT) \
      || ( echo "Out of space? the tree size of $(TARGET_OUT) is (MB): " 1>&2 ;\
           du -sm $(TARGET_OUT) 1>&2;\
           if [ "$(INTERNAL_USERIMAGES_EXT_VARIANT)" == "ext4" ]; then \
               maxsize=$(BOARD_SYSTEMIMAGE_PARTITION_SIZE); \
               echo "The max is $$(( maxsize / 1048576 )) MB." 1>&2 ;\
           else \
               echo "The max is $$(( $(BOARD_SYSTEMIMAGE_PARTITION_SIZE) / 1048576 )) MB." 1>&2 ;\
           fi; \
           mkdir -p $(DIST_DIR); cp $(INSTALLED_FILES_FILE) $(DIST_DIR)/installed-files-rescued.txt; \
           exit 1 )
endef
```

1.　调用create-system-vendor-symlink，定义为空
2.　调用create-system-product-symlink, 定义为空
3.　创建相关的目录，删除上次编译遗留的`system_image_info.txt`
4.　调用generate-userimage-prop-dictionary方法，生成`system_image_info.txt`，保存的是systemimage的信息，如文件类型，system分区大小等等。
5.　根据`system_image_info.txt`,使用`build_image.py`生成system.img固件。假如生成的结果有异常，则会给出提示是否是空间不足。


`build_iamge.py`根据当前配置的文件类型生成固件，如当前fstab.xxx对system分区的配置如下:

```makefile
/dev/block/by-name/system                              /            ext4     ro,barrier=1                 wait,recoveryonly
```

则生成的`system_image_info.txt`也对应了ext4格式，那么在`build_image.py`将会使用`mkuserimg_mk2fs.sh`生成固件。

```makefile
# system_image_info.txt
ext_mkuserimg=mkuserimg_mke2fs.sh
fs_type=ext4
system_size=1610612736
system_fs_type=ext4
cache_fs_type=ext4
cache_size=671088640
vendor_fs_type=ext4
vendor_size=251658240
extfs_sparse_flag=-s
squashfs_sparse_flag=-s
selinux_fc=out/target/product/xxxx/obj/ETC/file_contexts.bin_intermediates/file_contexts.bin
boot_signer=false
verity=true
verity_key=build/target/product/security/verity
verity_signer_cmd=verity_signer
verity_fec=true
verity_disable=true
system_verity_block_device=/dev/block/by-name/system
vendor_verity_block_device=/dev/block/by-name/vendor
system_root_image=true
ramdisk_dir=out/target/product/xxxx/root
skip_fsck=true
```

```python
# build_image.py
if fs_type.startswith("ext"):
    build_command = [prop_dict["ext_mkuserimg"]]
    if "extfs_sparse_flag" in prop_dict:
      build_command.append(prop_dict["extfs_sparse_flag"])
      run_e2fsck = True
    build_command.extend([in_dir, out_file, fs_type,
                          prop_dict["mount_point"]])
    build_command.append(prop_dict["partition_size"])
    if "journal_size" in prop_dict:
      build_command.extend(["-j", prop_dict["journal_size"]])
    if "timestamp" in prop_dict:
      build_command.extend(["-T", str(prop_dict["timestamp"])])
    if fs_config:
      build_command.extend(["-C", fs_config])
    if target_out:
      build_command.extend(["-D", target_out])
    if "block_list" in prop_dict:
      build_command.extend(["-B", prop_dict["block_list"]])
    if "base_fs_file" in prop_dict:
      base_fs_file = ConvertBlockMapToBaseFs(prop_dict["base_fs_file"])
      if base_fs_file is None:
        return False
      build_command.extend(["-d", base_fs_file])
    build_command.extend(["-L", prop_dict["mount_point"]])
    if "extfs_inode_count" in prop_dict:
      build_command.extend(["-i", prop_dict["extfs_inode_count"]])
    if "extfs_rsv_pct" in prop_dict:
      build_command.extend(["-M", prop_dict["extfs_rsv_pct"]])
    if "flash_erase_block_size" in prop_dict:
      build_command.extend(["-e", prop_dict["flash_erase_block_size"]])
    if "flash_logical_block_size" in prop_dict:
      build_command.extend(["-o", prop_dict["flash_logical_block_size"]])
    # Specify UUID and hash_seed if using mke2fs.
    if prop_dict["ext_mkuserimg"] == "mkuserimg_mke2fs.sh":
      if "uuid" in prop_dict:
        build_command.extend(["-U", prop_dict["uuid"]])
      if "hash_seed" in prop_dict:
        build_command.extend(["-S", prop_dict["hash_seed"]])
    if "ext4_share_dup_blocks" in prop_dict:
      build_command.append("-c")
    if "selinux_fc" in prop_dict:
      build_command.append(prop_dict["selinux_fc"])
...
  (mkfs_output, exit_code) = RunCommand(build_command)
```

至此，完成所有systemiamge的分析。


## 2.3 boot.img

droidcore除了依赖systemimage,还会依赖其他镜像，如`INSTALLED_BOOTIMAGE_TARGET`,

```makefile
# main.mk
.PHONY: bootimage
bootimage: $(INSTALLED_BOOTIMAGE_TARGET)

# Makefile
INSTALLED_BOOTIMAGE_TARGET := $(PRODUCT_OUT)/boot.img
```


`INSTALLED_BOOTIMAGE_TARGET`依赖MKBOOTIMG(mkbootimg),AVBTOOL(avbtool),`INTERNAL_BOOTIMAGE_FILES(kernel的位置)`以及`BOARD_AVB_BOOT_KEY_PATH`。

boot.img包括了kernel(bImage)以及ramdisk，后续将会根据这个思路去看如何制作boot.img固件。

```makefile
$(INSTALLED_BOOTIMAGE_TARGET): $(MKBOOTIMG) $(AVBTOOL) $(INTERNAL_BOOTIMAGE_FILES) $(BOARD_AVB_BOOT_KEY_PATH)
	$(call pretty,"Target boot image: $@")
	$(hide) $(MKBOOTIMG) $(INTERNAL_BOOTIMAGE_ARGS) $(INTERNAL_MKBOOTIMG_VERSION_ARGS) $(BOARD_MKBOOTIMG_ARGS) --output $@
	$(hide) $(call assert-max-image-size,$@,$(call get-hash-image-max-size,$(BOARD_BOOTIMAGE_PARTITION_SIZE)))
	$(hide) $(AVBTOOL) add_hash_footer \
	  --image $@ \
	  --partition_size $(BOARD_BOOTIMAGE_PARTITION_SIZE) \
	  --partition_name boot $(INTERNAL_AVB_BOOT_SIGNING_ARGS) \
	  $(BOARD_AVB_BOOT_ADD_HASH_FOOTER_ARGS)
```

`INTERNAL_BOOTIMAGE_ARGS`的赋值如下,主要定义了kernel的目录，起始地址，cmdline内容，编译类型(eng?),veritykey等信息。

```makefile
INTERNAL_BOOTIMAGE_ARGS := \
	$(addprefix --second ,$(INSTALLED_2NDBOOTLOADER_TARGET)) \
	--kernel $(INSTALLED_KERNEL_TARGET)

ifneq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
INTERNAL_BOOTIMAGE_ARGS += --ramdisk $(INSTALLED_RAMDISK_TARGET)
endif

INTERNAL_BOOTIMAGE_FILES := $(filter-out --%,$(INTERNAL_BOOTIMAGE_ARGS))

ifdef BOARD_KERNEL_BASE
  INTERNAL_BOOTIMAGE_ARGS += --base $(BOARD_KERNEL_BASE)
endif

ifdef BOARD_KERNEL_PAGESIZE
  INTERNAL_BOOTIMAGE_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
endif

INTERNAL_KERNEL_CMDLINE := $(strip $(BOARD_KERNEL_CMDLINE) buildvariant=$(TARGET_BUILD_VARIANT) $(VERITY_KEYID))
ifdef INTERNAL_KERNEL_CMDLINE
INTERNAL_BOOTIMAGE_ARGS += --cmdline "$(INTERNAL_KERNEL_CMDLINE)"
endif
```

`INTERNAL_MKBOOTIMG_VERSION_ARGS`保存的包括版本号以及打上安全补丁的日期(根据安全补丁，可以知道该SDK修复了哪些安全漏洞)。

```makefile
INTERNAL_MKBOOTIMG_VERSION_ARGS := \
    --os_version $(PLATFORM_VERSION) \
    --os_patch_level $(PLATFORM_SECURITY_PATCH)
```

mkbootimg根据输入参数生成boot.img其中需要注意的是mkbootimg解析的参数:

1. `--kernel`: kernel的路径
2. `--ramdisk`: ramdisk的路径
3. `--cmdline`: kernel的cmdline
4. `--base`: 基地址
5. `--kernel_offset`：kernel相对于基地址的偏移
6. `--ramdisk_offset`：ramdisk相对于基地址的偏移
7. `--pagesize`：页大小，默认为2k


Android N的boot.img分布：

```
|------|-----------------|-------------------------|--------------------|
base  boot.img头部      kernel地址                ramdisk地址
```

要注意的是，第一，开始将boot.img放入某个逻辑地址中，当解压的时候，boot.img开始存放的位置不能与被解压的地址有重叠，否则会出现原有boot.img的数据被覆盖，而导致解压失败。第二, 定义`ramdisk_offset`的偏移，不能过小，kernel放置的范围在(`base+kernel_offset`-`base+ramdisk_offset`),假如kernel大小偏大，越过了ramdisk的起始地址，在运行时，就会破坏ramdisk的原有数据，导致启动失败。简单计算一下当前正常启动的boot.img信息:

- base为0x40000000,`kernel_offset`为0x80000,则kernel地址为0x40080000。
- `ramdisk_offset`为0x02000000，ramdisk的地址为0x42000000。
- 留给kernel存放的大小为0x1F80000，换算为大小为31M。实际kernel大小为18M，完全能够容纳。

Android P发生了变化，ramdisk并没有和boot.img放在一起，而是放在了system分区．在方案的BoardConfig.mk中设置了`BOARD_BUILD_SYSTEM_ROOT_IMAGE`为true, 所以`--ramdisk`参数是为空的．

|预留kernel空间|Android P(boot.img 18 M)|Android N(boot.img 14M)|
|:--:|:--:|:--:|
|20M|正常启动|正常启动|
|10M|正常启动|无法启动|


再来看下boot.img header的定义，与实际boot.img的进行对比，以后从boot.img的hex就可以分析出boot.img的信息了:

```c
#define BOOT_MAGIC_SIZE 8
...
struct boot_img_hdr_v0 {
    uint8_t magic[BOOT_MAGIC_SIZE];

    uint32_t kernel_size; /* size in bytes */
    uint32_t kernel_addr; /* physical load addr */

    uint32_t ramdisk_size; /* size in bytes */
    uint32_t ramdisk_addr; /* physical load addr */

    uint32_t second_size; /* size in bytes */
    uint32_t second_addr; /* physical load addr */

    uint32_t tags_addr; /* physical addr for kernel tags */
    uint32_t page_size; /* flash page size we assume */
    /*
     * version for the boot image header.
     */
    uint32_t header_version;

    /* operating system version and security patch level; for
     * version "A.B.C" and patch level "Y-M-D":
     * ver = A << 14 | B << 7 | C         (7 bits for each of A, B, C)
     * lvl = ((Y - 2000) & 127) << 4 | M  (7 bits for Y, 4 bits for M)
     * os_version = ver << 11 | lvl */
    uint32_t os_version;

    uint8_t name[BOOT_NAME_SIZE]; /* asciiz product name */

    uint8_t cmdline[BOOT_ARGS_SIZE];

    uint32_t id[8]; /* timestamp / checksum / sha1 / etc */

    /* Supplemental command line data; kept here to maintain
     * binary compatibility with older versions of mkbootimg */
    uint8_t extra_cmdline[BOOT_EXTRA_ARGS_SIZE];
} __attribute__((packed));

```

使用vim打开boot.img并随后运行`:%!xxd`,显示的hex数据如下:

```
0000000: 414e 4452 4f49 4421 0878 1601 0000 0840  ANDROID!.x.....@
0000010: 0000 0000 0000 3f40 0000 0000 0000 3f40  ......?@......?@
0000020: 0001 0040 0008 0000 0100 0000 3201 0012  ...@........2...
0000030: 0000 0000 0000 0000 0000 0000 0000 0000  ................
0000040: 7365 6c69 6e75 783d 3120 616e 6472 6f69  selinux=1 androi
0000050: 6462 6f6f 742e 7365 6c69 6e75 783d 656e  dboot.selinux=en
0000060: 666f 7263 696e 6720 616e 6472 6f69 6462  forcing androidb
0000070: 6f6f 742e 6474 626f 5f69 6478 3d30 2c31  oot.dtbo_idx=0,1
0000080: 2c32 2062 7569 6c64 7661 7269 616e 743d  ,2 buildvariant=
0000090: 656e 6720 7665 7269 7479 6b65 7969 643d  eng veritykeyid=
00000a0: 6964 3a37 6534 3333 3366 3962 6261 3030  id:7e4333f9bba00
00000b0: 6164 6665 3065 6465 3937 3965 3238 6564  adfe0ede979e28ed
00000c0: 3139 3230 3439 3262 3430 6600 0000 0000  1920492b40f.....
```

1. magic魔数64位，即ANDROID!,对应414e 4452 4f49 4421
2. kernel大小共32位,即0x01167808,换算为十进制大小为17M
3. kernel地址为0x40080000.
4. ramdisk大小为0x00000000,Android P中ramdisk已经不在boot.img中放置了.

那么Android P中中ramdisk不放置在boot.img中，是如何处理呢?当BoardConfig中设置了`BOARD_BUILD_SYSTEM_ROOT_IMAGE`表明system.img中放置ramdisk内容,在生成system.img时，上述提到，会生成`system_image_info.txt`,并在其中增添`ramdisk_dir`的变量，指向root目录．

```makefile
$(if $(filter true,$(BOARD_BUILD_SYSTEM_ROOT_IMAGE)),\
    $(hide) echo "system_root_image=true" >> $(1);\
    echo "ramdisk_dir=$(TARGET_ROOT_OUT)" >> $(1))
$(if $(2),$(hide) $(foreach kv,$(2),echo "$(kv)" >> $(1);))
```

在运行`build_image`脚本时，会针对是否设置了该属性，去处理ramdisk的内容,将`ramdisk_dir`的内容拷贝至`in_dir`目录，并创建一个system目录，将原有system内容拷贝进去．

```python
    ramdisk_dir = prop_dict.get("ramdisk_dir")
    if ramdisk_dir:
      shutil.rmtree(in_dir)
      shutil.copytree(ramdisk_dir, in_dir, symlinks=True)
    staging_system = os.path.join(in_dir, "system")
    shutil.rmtree(staging_system, ignore_errors=True)
    shutil.copytree(origin_in, staging_system, symlinks=True)
```

## 2.4 files

files是droidcore的依赖首项:

```makefile
.PHONY: droidcore
droidcore: files \
    ...
```

files依赖`modules_to_install`和`INTALLED_ANDROID_INFO_TXT_TARGET`,前者在之前分析systemimage时已经分析过，就不予以分析，现在看来有部分目标是会存在重叠，比如systemimage和files，files指代的是目录里面的文件，而这些对于systemimage来说，也是需要的．

```makefile
.PHONY: files
files: $(modules_to_install) \
       $(INSTALLED_ANDROID_INFO_TXT_TARGET)

```

`INSTALLD_ANDROID_INFO_TXT_TARGET`是名为android-info.txt,首先会检查`board_info.txt`是否有定义,假如没有，则将`TARGET_BOOTLOADER_BOARD_NAME`记录在android-info.txt文件中．
，
```makefile
# Generate a file that contains various information about the
# device we're building for.  This file is typically packaged up
# with everything else.
#
# If TARGET_BOARD_INFO_FILE (which can be set in BoardConfig.mk) is
# defined, it is used, otherwise board-info.txt is looked for in
# $(TARGET_DEVICE_DIR).
#
INSTALLED_ANDROID_INFO_TXT_TARGET := $(PRODUCT_OUT)/android-info.txt
board_info_txt := $(TARGET_BOARD_INFO_FILE)
ifndef board_info_txt
board_info_txt := $(wildcard $(TARGET_DEVICE_DIR)/board-info.txt)
endif
$(INSTALLED_ANDROID_INFO_TXT_TARGET): $(board_info_txt)
	$(hide) build/make/tools/check_radio_versions.py $< $(BOARD_INFO_CHECK)
	$(call pretty,"Generated: ($@)")
ifdef board_info_txt
	$(hide) grep -v '#' $< > $@
else
	$(hide) echo "board=$(TARGET_BOOTLOADER_BOARD_NAME)" > $@
endif
```


## 2.5 vendorimage

droidcore中还依赖与vendor相关的`INSTALLED_VENDORIMAGE_TARGET`变量，Android N没有生成独立的vendor.img镜像，是由于没有定义变量`BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE`以及`TARGET_COPY_OUT_VENDOR`,当定义了这两个变量时，就会生成独立的vendor.img,而不是将vendor编进去system.img中．自Android O起，由于需要实现vndk,厂商的vendor内容就和system进行了分离．

```makefile
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_VENDOR := vendor
```

假如定义了`BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE`，`INTERNAL_VENDORIMAGE_FILES`就会过滤需安装的模块`ALL_DEFAULT_INSTALLD_MODULS`并匹配`TARGET_OUT_VENDOR`目录下的模块．

```makefile
# vendor partition image
ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
INTERNAL_VENDORIMAGE_FILES := \
    $(filter $(TARGET_OUT_VENDOR)/%,\
      $(ALL_DEFAULT_INSTALLED_MODULES)\
      $(ALL_PDK_FUSION_FILES)) \
    $(PDK_FUSION_SYMLINK_STAMP)
```

调用build-vendorimage-target制作vendor.img．

```makefile
vendorimage_intermediates := \
    $(call intermediates-dir-for,PACKAGING,vendor)
BUILT_VENDORIMAGE_TARGET := $(PRODUCT_OUT)/vendor.img
...
# We just build this directly to the install location.
INSTALLED_VENDORIMAGE_TARGET := $(BUILT_VENDORIMAGE_TARGET)
$(INSTALLED_VENDORIMAGE_TARGET): $(INTERNAL_USERIMAGES_DEPS) $(INTERNAL_VENDORIMAGE_FILES) $(INSTALLED_FILES_FILE_VENDOR) $(BUILD_IMAGE_SRCS) $(DEPMOD) $(BOARD_VENDOR_KERNEL_MODULES)
	$(build-vendorimage-target)
```

制作vendor.img与制作system.img类同，都使用了`build_image.py`.

```makefile
define build-vendorimage-target
  $(call pretty,"Target vendor fs image: $(INSTALLED_VENDORIMAGE_TARGET)")
  @mkdir -p $(TARGET_OUT_VENDOR)
  @mkdir -p $(vendorimage_intermediates) && rm -rf $(vendorimage_intermediates)/vendor_image_info.txt
  $(call generate-userimage-prop-dictionary, $(vendorimage_intermediates)/vendor_image_info.txt, skip_fsck=true)
  $(if $(BOARD_VENDOR_KERNEL_MODULES), \
    $(call build-image-kernel-modules,$(BOARD_VENDOR_KERNEL_MODULES),$(TARGET_OUT_VENDOR),vendor/,$(call intermediates-dir-for,PACKAGING,depmod_vendor)))
  $(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH \
      build/make/tools/releasetools/build_image.py \
      $(TARGET_OUT_VENDOR) $(vendorimage_intermediates)/vendor_image_info.txt $(INSTALLED_VENDORIMAGE_TARGET) $(TARGET_OUT)
  $(hide) $(call assert-max-image-size,$(INSTALLED_VENDORIMAGE_TARGET),$(BOARD_VENDORIMAGE_PARTITION_SIZE))
endef
```

## 2.6 import-products

在上述生成systemimage时，提及过对`product_MODULES`进行了赋值，当时并没有深入解释`$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES)`这个值是怎么生成，现在进行详细分析．

```makefile
product_MODULES := $(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PACKAGES)
```

当进行编译时，当进行到`product_config.mk`时，将会运行到如下语句，即对当前的方案makefile进行产品的导入，`current_product_makefile`值即为`/device/xxxx/xxx.mk`

```makefile
$(call import-products, $(current_product_makefile))
```

此时PRODUCTS作为一个prefix传入，作为import-nodes方法的`$1`,方案Makefile作为`$2`,`_product_var_list`内容为一系列以PRODUCT开头的变量，如`PRODUCT_NAME`,`PRODUCT_MODEL`等等．

```makefile
define import-products
$(call import-nodes,PRODUCTS,$(1),$(_product_var_list))
endef
```

```makefile
define import-nodes
$(if \
  $(foreach _in,$(2), \
    $(eval _node_import_context := _nic.$(1).[[$(_in)]]) \
    $(if $(_include_stack),$(eval $(error ASSERTION FAILED: _include_stack \
                should be empty here: $(_include_stack))),) \
    $(eval _include_stack := ) \
    $(call _import-nodes-inner,$(_node_import_context),$(_in),$(3)) \
    $(call move-var-list,$(_node_import_context).$(_in),$(1).$(_in),$(3)) \
    $(eval _node_import_context :=) \
    $(eval $(1) := $($(1)) $(_in)) \
    $(if $(_include_stack),$(eval $(error ASSERTION FAILED: _include_stack \
                should be empty here: $(_include_stack))),) \
   ) \
,)
```

1.import-nodes首先遍历方案Makefile，找到一个node节点,`_node_import_context`，并进行赋值，即:`_nic.PRODUCTS.[[device/xxx/xxx.mk]]`.这个例子中，`current_product_makefile`中只有一个节点．
2.紧接着以该节点为向上上溯，调用`_import-nodes-inner`.其中`$1`为`_node_import_context`，`$2`为方案Makefile，`$3`为
`_product_var_list`.

```makefile
define _import-nodes-inner
  $(foreach _in,$(2), \
    $(if $(wildcard $(_in)), \
      $(if $($(1).$(_in).seen), \
        $(eval ### "skipping already-imported $(_in)") \
       , \
        $(eval $(1).$(_in).seen := true) \
        $(call _import-node,$(1),$(strip $(_in)),$(3)) \
       ) \
     , \
      $(error $(1): "$(_in)" does not exist) \
     ) \
   )
endef
```

当`$($(1).$(_in).seen`不存在时，将会对该Makefile进行赋值`$(1).$(_in).seen := true`,表明该Makefile可见．并调用`_import-node`对该nic节点处理．

3.`_import-node`输入参数分别为`$1`为nic节点，`$2`为makefile，此处仍然指的是方案Makefile,`$3`为`_product_var_list`.

```makefile
#
# $(1): context prefix
# $(2): makefile representing this node
# $(3): list of node variable names
#
# _include_stack contains the list of included files, with the most recent files first.
define _import-node
  $(eval _include_stack := $(2) $$(_include_stack))
  $(call clear-var-list, $(3))
  $(eval LOCAL_PATH := $(patsubst %/,%,$(dir $(2))))
  $(eval MAKEFILE_LIST :=)
  $(eval include $(2))
  $(eval _included := $(filter-out $(2),$(MAKEFILE_LIST)))
  $(eval MAKEFILE_LIST :=)
  $(eval LOCAL_PATH :=)
  $(call copy-var-list, $(1).$(2), $(3))
  $(call clear-var-list, $(3))

  $(eval $(1).$(2).inherited := \
      $(call get-inherited-nodes,$(1).$(2),$(3)))
  $(warning inherited = $(1).$(2).inherited)
  $(call _import-nodes-inner,$(1),$($(1).$(2).inherited),$(3))

  $(call _expand-inherited-values,$(1),$(2),$(3))

  $(eval $(1).$(2).inherited :=)
  $(eval _include_stack := $(wordlist 2,9999,$$(_include_stack)))
endef
```

首先调用`include $(2))`,加载方案Makefile.然后调用copy-var-list,该方法会形式如下,将会将A的值，拷贝到PREFIX.A中．

```makefile
# E.g.,
#   $(call copy-var-list, PREFIX, A B)
# would be the same as:
#   PREFIX.A := $(A)
#   PREFIX.B := $(B)
#
# $(1): destination prefix
# $(2): list of variable names to copy
#
define copy-var-list
$(foreach v,$(2),$(eval $(strip $(1)).$(v):=$($(v))))
endef
```

那么调用该方法后，就会将`_nic.PRODUCT.[[device/xxx/xxx.mk]].device/xxx/xxx.mk.PRODCT_NAME`的值，变为`$(PRODUCT_NAME)`，余此类推还有在`_product_var_list`的内容．实质上只是单纯将`__product_var_list`的内容增加了前缀.由此解释了这些变量是在哪个阶段被赋值．

之后调用get-inherited-nodes,能够获取所有device/xxx/xxx.mk中继承的mk列表.并重新调用`_import-nodes-inner`对继承的Makefile继续处理．由此将所有关联的Makefile进行处理.
