---
layout:     post
title:      "Android P编译简析[三]"
summary:    '"build system"'
date:       2019-04-08 17:44:00
author:     "Bill"
header-img: "img/bill/header-posts/2019-01-17.jpg"
catalog: true
tags:
    - android
    - build
---


<!-- vim-markdown-toc GFM -->

* [3. 编译OTA升级包](#3-编译ota升级包)

<!-- vim-markdown-toc -->

# 3. 编译OTA升级包

传统生成OTA包时，只需运行make otapackage即可，如下所示:

```makefile
$(INTERNAL_OTA_PACKAGE_TARGET): $(BUILT_TARGET_FILES_PACKAGE) \
		build/make/tools/releasetools/ota_from_target_files
	@echo "Package OTA: $@"
	$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	   build/make/tools/releasetools/ota_from_target_files -v \
	   --block \
	   --extracted_input_target_files $(patsubst %.zip,%,$(BUILT_TARGET_FILES_PACKAGE)) \
	   -p $(HOST_OUT) \
	   -k $(KEY_CERT_PAIR) \
	   $(if $(OEM_OTA_CONFIG), -o $(OEM_OTA_CONFIG)) \
	   $(BUILT_TARGET_FILES_PACKAGE) $@

.PHONY: otapackage
otapackage: $(INTERNAL_OTA_PACKAGE_TARGET)
```

`BUILT_TARGET_FILS_PACKAGES`即targetfile，在制作OTA包时，首先要确认targetfile是生成的:

```makefile
# -----------------------------------------------------------------
# A zip of the directories that map to the target filesystem.
# This zip can be used to create an OTA package or filesystem image
# as a post-build step.
#
name := $(TARGET_PRODUCT)
ifeq ($(TARGET_BUILD_TYPE),debug)
  name := $(name)_debug
endif
name := $(name)-target_files-$(FILE_NAME_TAG)

intermediates := $(call intermediates-dir-for,PACKAGING,target_files)
BUILT_TARGET_FILES_PACKAGE := $(intermediates)/$(name).zip
$(BUILT_TARGET_FILES_PACKAGE): intermediates := $(intermediates)
$(BUILT_TARGET_FILES_PACKAGE): \
		zip_root := $(intermediates)/$(name)
...
built_ota_tools :=
...
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_OTA_TOOLS := $(built_ota_tools)

$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_API_VERSION := $(RECOVERY_API_VERSION)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_FSTAB_VERSION := $(RECOVERY_FSTAB_VERSION)

ifeq ($(TARGET_RELEASETOOLS_EXTENSIONS),)
# default to common dir for device vendor
tool_extensions := $(TARGET_DEVICE_DIR)/../common
else
tool_extensions := $(TARGET_RELEASETOOLS_EXTENSIONS)
endif
tool_extension := $(wildcard $(tool_extensions)/releasetools.py)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_TOOL_EXTENSIONS := $(tool_extensions)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_TOOL_EXTENSION := $(tool_extension)

ifeq ($(AB_OTA_UPDATER),true)
updater_dep := system/update_engine/update_engine.conf
else
# Build OTA tools if not using the AB Updater.
updater_dep := $(built_ota_tools)
endif
$(BUILT_TARGET_FILES_PACKAGE): $(updater_dep)

# If we are using recovery as boot, output recovery files to BOOT/.
ifeq ($(BOARD_USES_RECOVERY_AS_BOOT),true)
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_OUT := BOOT
else
$(BUILT_TARGET_FILES_PACKAGE): PRIVATE_RECOVERY_OUT := RECOVERY
endif

ifeq ($(AB_OTA_UPDATER),true)
  ifdef BRILLO_VENDOR_PARTITIONS
    $(BUILT_TARGET_FILES_PACKAGE): $(foreach p,$(BRILLO_VENDOR_PARTITIONS),\
                                     $(call word-colon,1,$(p))/$(call word-colon,2,$(p)))
  endif
  ifdef OSRELEASED_DIRECTORY
    $(BUILT_TARGET_FILES_PACKAGE): $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_id
    $(BUILT_TARGET_FILES_PACKAGE): $(TARGET_OUT_OEM)/$(OSRELEASED_DIRECTORY)/product_version
    $(BUILT_TARGET_FILES_PACKAGE): $(TARGET_OUT_ETC)/$(OSRELEASED_DIRECTORY)/system_version
  endif
endif
....

# Depending on the various images guarantees that the underlying
# directories are up-to-date.
$(BUILT_TARGET_FILES_PACKAGE): \
		$(INSTALLED_BOOTIMAGE_TARGET) \
		$(INSTALLED_RADIOIMAGE_TARGET) \
		$(INSTALLED_RECOVERYIMAGE_TARGET) \
		$(FULL_SYSTEMIMAGE_DEPS) \
		$(INSTALLED_USERDATAIMAGE_TARGET) \
		$(INSTALLED_CACHEIMAGE_TARGET) \
		$(INSTALLED_VENDORIMAGE_TARGET) \
		$(INSTALLED_PRODUCTIMAGE_TARGET) \
		$(INSTALLED_VBMETAIMAGE_TARGET) \
		$(INSTALLED_DTBOIMAGE_TARGET) \
		$(INTERNAL_SYSTEMOTHERIMAGE_FILES) \
		$(INSTALLED_ANDROID_INFO_TXT_TARGET) \
		$(INSTALLED_KERNEL_TARGET) \
		$(INSTALLED_2NDBOOTLOADER_TARGET) \
		$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_SYSTEM_BASE_FS_PATH) \
		$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_VENDOR_BASE_FS_PATH) \
		$(PRODUCTS.$(INTERNAL_PRODUCT).PRODUCT_PRODUCT_BASE_FS_PATH) \
		$(SELINUX_FC) \
		$(APKCERTS_FILE) \
		$(SOONG_ZIP) \
		$(HOST_OUT_EXECUTABLES)/fs_config \
		$(HOST_OUT_EXECUTABLES)/imgdiff \
		$(HOST_OUT_EXECUTABLES)/bsdiff \
		$(BUILD_IMAGE_SRCS) \
		$(BUILT_VENDOR_MANIFEST) \
		$(BUILT_VENDOR_MATRIX) \
		| $(ACP)
	@echo "Package target files: $@"
	$(call create-system-vendor-symlink)
	$(call create-system-product-symlink)
	$(hide) rm -rf $@ $@.list $(zip_root)
	$(hide) mkdir -p $(dir $@) $(zip_root)
```


`BUILT_TARGET_FILES_PACKAGES`依赖的内容与droidcore中有重合，并且还需要依赖如imgdiff，bsdiff等工具用以制作差分包，创建`zip_root`目录，用以放置需要制作targetfile的内容．生成zip包文件格式如`$(name)-target_files-$(FILE_NAME_TAG)`

```makefile
ifneq (,$(INSTALLED_RECOVERYIMAGE_TARGET)$(filter true,$(BOARD_USES_RECOVERY_AS_BOOT)))
	@# Components of the recovery image
	$(hide) mkdir -p $(zip_root)/$(PRIVATE_RECOVERY_OUT)
	$(hide) $(call package_files-copy-root, \
		$(TARGET_RECOVERY_ROOT_OUT),$(zip_root)/$(PRIVATE_RECOVERY_OUT)/RAMDISK)
ifdef INSTALLED_KERNEL_TARGET
	$(hide) cp $(INSTALLED_KERNEL_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/kernel
endif
ifdef INSTALLED_2NDBOOTLOADER_TARGET
	$(hide) cp $(INSTALLED_2NDBOOTLOADER_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/second
endif
ifdef BOARD_INCLUDE_RECOVERY_DTBO
	$(hide) cp $(INSTALLED_DTBOIMAGE_TARGET) $(zip_root)/$(PRIVATE_RECOVERY_OUT)/recovery_dtbo
endif
ifdef INTERNAL_KERNEL_CMDLINE
	$(hide) echo "$(INTERNAL_KERNEL_CMDLINE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/cmdline
endif
ifdef BOARD_KERNEL_BASE
	$(hide) echo "$(BOARD_KERNEL_BASE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/base
endif
ifdef BOARD_KERNEL_PAGESIZE
	$(hide) echo "$(BOARD_KERNEL_PAGESIZE)" > $(zip_root)/$(PRIVATE_RECOVERY_OUT)/pagesize
endif
$(hide) mkdir -p $(zip_root)/BOOT
ifeq ($(BOARD_BUILD_SYSTEM_ROOT_IMAGE),true)
	$(hide) mkdir -p $(zip_root)/ROOT
	$(hide) $(call package_files-copy-root, \
		$(TARGET_ROOT_OUT),$(zip_root)/ROOT)
else
	$(hide) $(call package_files-copy-root, \
		$(TARGET_ROOT_OUT),$(zip_root)/BOOT/RAMDISK)
endif
```

经过这波操作，在`zip_root`/RECOVERY填充了如下文件:

- base
- kernel
- cmdline
- `recovery_dtbo`
- RAMDISK //即root文件夹

且如果为`BOARD_BUILD_SYSTEM_ROOT_IMAGE`，则BOOT目录下是不带RAMDISK目录的．

```makefile
$(hide) $(call package_files-copy-root, \
		$(SYSTEMIMAGE_SOURCE_DIR),$(zip_root)/SYSTEM)
	@# Contents of the data image
	$(hide) $(call package_files-copy-root, \
		$(TARGET_OUT_DATA),$(zip_root)/DATA)
ifdef BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE
	@# Contents of the vendor image
	$(hide) $(call package_files-copy-root, \
		$(TARGET_OUT_VENDOR),$(zip_root)/VENDOR)
endi
```

将SYSTEM,VENDOR目录原封不动拷贝过来．

```makefile
$(hide) mkdir -p $(zip_root)/OTA
	$(hide) cp $(INSTALLED_ANDROID_INFO_TXT_TARGET) $(zip_root)/OTA/
```
拷贝OTA相关以及updater可执行程序(用以在recovery中执行升级)进OTA目录下．

```makefile
$(hide) mkdir -p $(zip_root)/META
	$(hide) cp $(APKCERTS_FILE) $(zip_root)/META/apkcerts.txt
ifneq ($(tool_extension),)
	$(hide) cp $(PRIVATE_TOOL_EXTENSION) $(zip_root)/META/
endif
	$(hide) echo "$(PRODUCT_OTA_PUBLIC_KEYS)" > $(zip_root)/META/otakeys.txt
	$(hide) cp $(SELINUX_FC) $(zip_root)/META/file_contexts.bin
	$(hide) echo "recovery_api_version=$(PRIVATE_RECOVERY_API_VERSION)" > $(zip_root)/META/misc_info.txt
	$(hide) echo "fstab_version=$(PRIVATE_RECOVERY_FSTAB_VERSION)" >> $(zip_root)/META/misc_info.txt
ifdef BOARD_FLASH_BLOCK_SIZE
	$(hide) echo "blocksize=$(BOARD_FLASH_BLOCK_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_BOOTIMAGE_PARTITION_SIZE
	$(hide) echo "boot_size=$(BOARD_BOOTIMAGE_PARTITION_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
ifeq ($(INSTALLED_RECOVERYIMAGE_TARGET),)
	$(hide) echo "no_recovery=true" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_INCLUDE_RECOVERY_DTBO
	$(hide) echo "include_recovery_dtbo=true" >> $(zip_root)/META/misc_info.txt
endif
ifdef BOARD_RECOVERYIMAGE_PARTITION_SIZE
	$(hide) echo "recovery_size=$(BOARD_RECOVERYIMAGE_PARTITION_SIZE)" >> $(zip_root)/META/misc_info.txt
endif
ifdef TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS
	@# TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS can be empty to indicate that nothing but defaults should be used.
	$(hide) echo "recovery_mount_options=$(TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS)" >> $(zip_root)/META/misc_info.txt
else
	$(hide) echo "recovery_mount_options=$(DEFAULT_TARGET_RECOVERY_FSTYPE_MOUNT_OPTIONS)" >> $(zip_root)/META/misc_info.txt
endif
	$(hide) echo "tool_extensions=$(PRIVATE_TOOL_EXTENSIONS)" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "default_system_dev_certificate=$(DEFAULT_SYSTEM_DEV_CERTIFICATE)" >> $(zip_root)/META/misc_info.txt
ifdef PRODUCT_EXTRA_RECOVERY_KEYS
	$(hide) echo "extra_recovery_keys=$(PRODUCT_EXTRA_RECOVERY_KEYS)" >> $(zip_root)/META/misc_info.txt
endif
	$(hide) echo 'mkbootimg_args=$(BOARD_MKBOOTIMG_ARGS)' >> $(zip_root)/META/misc_info.txt
	$(hide) echo 'mkbootimg_version_args=$(INTERNAL_MKBOOTIMG_VERSION_ARGS)' >> $(zip_root)/META/misc_info.txt
	$(hide) echo "multistage_support=1" >> $(zip_root)/META/misc_info.txt
	$(hide) echo "blockimgdiff_versions=3,4" >> $(zip_root)/META/misc_info.txt
...
```
此外还需要生成一份`misc_info.txt`文件，用以描述各分区的信息．

```makefile
$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	    build/make/tools/releasetools/add_img_to_target_files -a -v -p $(HOST_OUT) $(zip_root)
	@# Zip everything up, preserving symlinks and placing META/ files first to
	@# help early validation of the .zip file while uploading it.
	$(hide) find $(zip_root)/META | sort >$@.list
	$(hide) find $(zip_root) -path $(zip_root)/META -prune -o -print | sort >>$@.list
	$(hide) $(SOONG_ZIP) -d -o $@ -C $(zip_root) -l $@.list
```
最终生成`xxx-target_files.zip.list`文件，用以记录targetfile中的所有文件，并利用zip将所有内容压缩成zip包，至此，target-file生成．回过头再看如何生成OTA包．

```makefile
$(hide) PATH=$(foreach p,$(INTERNAL_USERIMAGES_BINARY_PATHS),$(p):)$$PATH MKBOOTIMG=$(MKBOOTIMG) \
	   build/make/tools/releasetools/ota_from_target_files -v \
	   --block \
	   --extracted_input_target_files $(patsubst %.zip,%,$(BUILT_TARGET_FILES_PACKAGE)) \
	   -p $(HOST_OUT) \
	   -k $(KEY_CERT_PAIR) \
	   $(if $(OEM_OTA_CONFIG), -o $(OEM_OTA_CONFIG)) \
	   $(BUILT_TARGET_FILES_PACKAGE) $@
```

1. 开始进行遍历，记得`INTERNAL_USERIMAGES_BINARY_PATHS`里记录的是许多工具，加进PATH中即可直接调用．
2. 利用`ota_from_target_files`生成OTA包．默认编译`--block`(AB升级必须是block),带`--extracted_input_target_files`时，读取`misc_info.txt`将不需要解压再获取．默认带`-k`默认签名testkey


