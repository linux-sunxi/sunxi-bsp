.PHONY: all clean help
.PHONY: android tools u-boot linux libs hwpack hwpack-install

CROSS_COMPILE=arm-linux-gnueabihf-
U_BOOT_CROSS_COMPILE=arm-linux-gnueabi-
OUTPUT_DIR=$(PWD)/output
BUILD_PATH=$(PWD)/build
ROOTFS?=norootfs
Q=
J=$(shell expr `grep ^processor /proc/cpuinfo  | wc -l` \* 2)

include chosen_board.mk

HWPACK=$(OUTPUT_DIR)/$(BOARD)_hwpack.7z
U_O_PATH=$(BUILD_PATH)/$(UBOOT_CONFIG)-u-boot
K_O_PATH=$(BUILD_PATH)/$(KERNEL_CONFIG)-linux
U_CONFIG_H=$(U_O_PATH)/include/config.h
K_DOT_CONFIG=$(K_O_PATH)/.config

all: hwpack

clean:
	rm -rf $(BUILD_PATH)
	rm -f chosen_board.mk

## tools
tools: sunxi-tools/.git
	$(Q)$(MAKE) -C sunxi-tools

## u-boot
$(U_CONFIG_H): u-boot-sunxi/.git
	$(Q)mkdir -p $(U_O_PATH)
	$(Q)$(MAKE) -C u-boot-sunxi $(UBOOT_CONFIG) O=$(U_O_PATH) CROSS_COMPILE=$(U_BOOT_CROSS_COMPILE) -j$J

u-boot: $(U_CONFIG_H)
	$(Q)$(MAKE) -C u-boot-sunxi O=$(U_O_PATH) CROSS_COMPILE=$(U_BOOT_CROSS_COMPILE) -j$J

## linux
$(K_DOT_CONFIG): linux-sunxi/.git
	$(Q)mkdir -p $(K_O_PATH)
	$(Q)$(MAKE) -C linux-sunxi O=$(K_O_PATH) ARCH=arm $(KERNEL_CONFIG)

linux: $(K_DOT_CONFIG)
	$(Q)$(MAKE) -C linux-sunxi O=$(K_O_PATH) ARCH=arm oldconfig
	$(Q)$(MAKE) -C linux-sunxi O=$(K_O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} -j$J INSTALL_MOD_PATH=output uImage modules
	$(Q)$(MAKE) -C linux-sunxi O=$(K_O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} -j$J INSTALL_MOD_PATH=output modules_install

## script.bin
script.bin: tools
	$(Q)mkdir -p $(OUTPUT_DIR)
	$(Q)sunxi-tools/fex2bin sunxi-boards/sys_config/$(SOC)/$(BOARD).fex > $(BUILD_PATH)/$(BOARD).bin

## boot.scr
boot.scr:
	$(Q)mkdir -p $(OUTPUT_DIR)
	$(Q)[ ! -s boot.cmd ] || mkimage -A arm -O u-boot -T script -C none -n "boot" -d boot.cmd $(BUILD_PATH)/boot.scr

## hwpack
$(HWPACK): u-boot boot.scr script.bin linux libs
	$(Q)scripts/mk_hwpack.sh $@

hwpack: $(HWPACK)

android:
	$(Q)scripts/mk_android.sh $@

hwpack-install: $(HWPACK)
ifndef SD_CARD
	$(Q)echo "Define SD_CARD variable"
	$(Q)false
else
	$(Q)scripts/a1x-media-create.sh $(SD_CARD) $(HWPACK) $(ROOTFS)
endif

libs: mali-libs/.git cedarx-libs/.git

update:
	$(Q)git submodule init
	$(Q)git submodule -q foreach git pull --rebase origin HEAD

%/.git:
	$(Q)git submodule init
	$(Q)git submodule update $*
