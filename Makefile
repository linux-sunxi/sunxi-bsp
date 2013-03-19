.PHONY: all clean help
.PHONY: tools u-boot linux libs hwpack hwpack-install
.PHONY: linux-config

SUDO=sudo
CROSS_COMPILE=arm-linux-gnueabihf-
OUTPUT_DIR=$(CURDIR)/output
BUILD_PATH=$(CURDIR)/build
ROOTFS?=norootfs
Q=
J=$(shell expr `grep ^processor /proc/cpuinfo  | wc -l` \* 2)

include chosen_board.mk

HWPACK=$(OUTPUT_DIR)/$(BOARD)_hwpack.tar.xz
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
	$(Q)$(MAKE) -C u-boot-sunxi $(UBOOT_CONFIG)_config O=$(U_O_PATH) CROSS_COMPILE=$(CROSS_COMPILE) -j$J

u-boot: $(U_CONFIG_H)
	$(Q)$(MAKE) -C u-boot-sunxi all O=$(U_O_PATH) CROSS_COMPILE=$(CROSS_COMPILE) -j$J

## linux
$(K_DOT_CONFIG): linux-sunxi/.git
	$(Q)mkdir -p $(K_O_PATH)
	$(Q)$(MAKE) -C linux-sunxi O=$(K_O_PATH) ARCH=arm $(KERNEL_CONFIG)

linux: $(K_DOT_CONFIG)
	$(Q)$(MAKE) -C linux-sunxi O=$(K_O_PATH) ARCH=arm oldconfig
	$(Q)$(MAKE) -C linux-sunxi O=$(K_O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} -j$J INSTALL_MOD_PATH=output uImage modules
	$(Q)$(MAKE) -C linux-sunxi O=$(K_O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} -j$J INSTALL_MOD_PATH=output modules_install
	cd $(K_O_PATH) && ${CROSS_COMPILE}objcopy -R .note.gnu.build-id -S -O binary vmlinux bImage

linux-config: linux-sunxi/.git
	$(Q)$(MAKE) -C linux-sunxi O=$(K_O_PATH) ARCH=arm menuconfig

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

android-%:
	$(Q)scripts/mk_android.sh $*

android: android-build

hwpack-install: $(HWPACK)
ifndef SD_CARD
	$(Q)echo "Define SD_CARD variable"
	$(Q)false
else
	$(Q)$(SUDO) scripts/sunxi-media-create.sh $(SD_CARD) $(HWPACK) $(ROOTFS)
endif

libs: cedarx-libs/.git

update:
	$(Q)git stash
	$(Q)git pull --rebase
	$(Q)git submodule -q init 
	$(Q)git submodule -q foreach git stash save -q --include-untracked "make update stash"
	-$(Q)git submodule -q foreach git fetch -q
	-$(Q)git submodule -q foreach "git rebase origin HEAD || :"
	-$(Q)git submodule -q foreach "git stash pop -q || :"
	-$(Q)git stash pop -q
	$(Q)git submodule status

%/.git:
	$(Q)git submodule init
	$(Q)git submodule update $*

help:
	@echo ""
	@echo "Usage:"
	@echo "  make hwpack          - Default 'make'"
	@echo "  make hwpack-install  - Builds and installs hwpack and optional rootfs to sdcard"
	@echo "   Arguments:"
	@echo "    SD_CARD=           - Target  (ie. /dev/sdx)"
	@echo "    ROOTFS=            - Source rootfs (ie. rootfs.tar.gz)"
	@echo ""
	@echo "  make android         - **Experimental**"
	@echo "  make livesuit        - ** To be done **"
	@echo "  make clean"
	@echo "  make update"
	@echo ""
	@echo "Optional targets:"
	@echo "  make linux           - Builds linux kernel"
	@echo "  make linux-config    - Menuconfig"
	@echo "  make u-boot          - Builds u-boot"
	@echo "  make libs            - Download libs"
	@echo ""

