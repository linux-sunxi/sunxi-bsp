include chosen_board.mk

.PHONY: all clean help
.PHONY: tools u-boot linux hwpack hwpack-install

CROSS_COMPILE=arm-linux-gnueabihf-
U_BOOT_CROSS_COMPILE=arm-linux-gnueabi-
OUTPUT_DIR=output
Q=
J=$(shell expr `grep ^processor /proc/cpuinfo  | wc -l` \* 2)

BUILD_PATH=$(PWD)/build

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
	$(Q)sunxi-tools/fex2bin sunxi-boards/sys_config/$(SOC)/$(BOARD).fex > $(OUTPUT_DIR)/$(BOARD).bin

## boot.scr
boot.scr:
	$(Q)mkdir -p $(OUTPUT_DIR)
	$(Q)[ -e boot.cmd ] && mkimage -A arm -O u-boot -T script -C none -n "boot" -d boot.cmd $(OUTPUT_DIR)/boot.scr ||echo

## hwpack
hwpack: u-boot boot.scr script.bin linux
	$(Q)echo WIP hwpack
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs

	$(Q)## Only support Debian/Ubuntu for now
	#$(Q)cp a10-config/rootfs/debian-ubuntu/* $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs -rf

	$(Q)## bins
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/usr/bin
	#$(Q)cp ../../a10-tools/a1x-initramfs.sh $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/usr/bin
	#$(Q)chmod 755 $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/usr/bin/a1x-initramfs.sh

	$(Q)## libs
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/bin-backup
	$(Q)cp mali-libs/r2p4/armhf/x11/* $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs -rf
	$(Q)cp mali-libs/r2p4/armhf/x11/* $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/bin-backup -rf

	$(Q)## kernel
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack/kernel
	$(Q)cp $(K_O_PATH)/arch/arm/boot/uImage $(OUTPUT_DIR)/$(BOARD)_hwpack/kernel/
	$(Q)cp $(OUTPUT_DIR)/$(BOARD).bin $(OUTPUT_DIR)/$(BOARD)_hwpack/kernel/
	$(Q)## boot.scr (optional)
	-$(Q)cp $(OUTPUT_DIR)/boot.scr $(OUTPUT_DIR)/$(BOARD)_hwpack/kernel/boot.scr 

	$(Q)## kernel modules
	$(Q)cp -a $(K_O_PATH)/output/lib/modules $(OUTPUT_DIR)/$(BOARD)_hwpack/rootfs/lib

	$(Q)## bootloader
	$(Q)mkdir -p $(OUTPUT_DIR)/$(BOARD)_hwpack/bootloader
	$(Q)cp $(U_O_PATH)/spl/sunxi-spl.bin $(OUTPUT_DIR)/$(BOARD)_hwpack/bootloader/
	$(Q)cp $(U_O_PATH)/u-boot.bin $(OUTPUT_DIR)/$(BOARD)_hwpack/bootloader/

	$(Q)## compress hwpack
	$(Q)cd $(OUTPUT_DIR)/$(BOARD)_hwpack/ && 7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../$(BOARD)_hwpack.7z .

hwpack-install: hwpack
ifndef SD_CARD
	$(Q)echo "Define SD_CARD variable"
else
	$(Q)scripts/a1x-media-create.sh $(SD_CARD) $(OUTPUT_DIR)/$(BOARD)_hwpack.7z norootfs
endif

update:
	$(Q)git submodule init
	$(Q)git submodule -q foreach git pull origin HEAD

%/.git:
	$(Q)git submodule init
	$(Q)[ -e $*/.git ] || git submodule update $*

