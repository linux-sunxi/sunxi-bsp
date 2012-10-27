.PHONY: all clean help
.PHONY: tools u-boot linux libs hwpack hwpack-install

CROSS_COMPILE=arm-linux-gnueabihf-
U_BOOT_CROSS_COMPILE=arm-linux-gnueabi-
OUTPUT_DIR=$(PWD)/output
BUILD_PATH=$(PWD)/build
Q=
J=$(shell expr `grep ^processor /proc/cpuinfo  | wc -l` \* 2)

include chosen_board.mk

all: hwpack

clean:
	rm -rf $(OUTPUT_DIR)
	rm -f chosen_board.mk

## tools
tools: sunxi-tools/.git
	$(Q)$(MAKE) -C sunxi-tools

## u-boot
U_O_PATH=$(BUILD_PATH)/u-boot-$(UBOOT_CONFIG)
U_CONFIG_MK=$(U_O_PATH)/include/config.mk

$(U_CONFIG_MK): u-boot-sunxi/.git
	$(Q)mkdir -p $(U_O_PATH)
	$(Q)$(MAKE) -C u-boot-sunxi $(UBOOT_CONFIG) O=$(U_O_PATH) CROSS_COMPILE=$(U_BOOT_CROSS_COMPILE) -j$J

u-boot: $(U_CONFIG_MK)
	$(Q)$(MAKE) -C u-boot-sunxi O=$(U_O_PATH) CROSS_COMPILE=$(U_BOOT_CROSS_COMPILE) -j$J

## linux
K_O_PATH=$(BUILD_PATH)/linux-$(KERNEL_CONFIG)
K_DOT_CONFIG=$(K_O_PATH)/.config

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
hwpack: u-boot boot.scr script.bin linux libs
	$(Q)scripts/mk_hwpack.sh

hwpack-install: hwpack
ifndef SD_CARD
	$(Q)echo "Define SD_CARD variable"
else
	$(Q)scripts/a1x-media-create.sh $(SD_CARD) $(OUTPUT_DIR)/$(BOARD)_hwpack.7z norootfs
endif

libs: mali-libs/.git cedarx-libs/.git

update:
	$(Q)git submodule init
	$(Q)git submodule -q foreach git pull origin HEAD

%/.git:
	$(Q)git submodule init
	$(Q)git submodule update $*
