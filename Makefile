.PHONY: all clean help
.PHONY: tools
.PHONY: submodule-init %-update u-boot linux hwpack

CROSS_COMPILE=arm-linux-gnueabihf-
OUTPUT_DIR=output

all: tools

clean:
	rm -f chosen_board.mk

tools: sunxi-tools-update
	$(MAKE) -C sunxi-tools

submodule-init:
	git submodule init

%-update: submodule-init
	[ -e $*/.git ] || git submodule update $*

u-boot: u-boot-sunxi-update
	$(MAKE) -C u-boot-sunxi $(UBOOT_CONFIG) CROSS_COMPILE=${CROSS_COMPILE}

O_PATH=build/linux-$(KERNEL_CONFIG)
linux: linux-sunxi-update
	$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm $(KERNEL_CONFIG)
	$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} uImage
	$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} INSTALL_MOD_PATH=$(O_PATH) modules
	$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILE} INSTALL_MOD_PATH=$(O_PATH) modules_install

script.bin: $(OUTPUT_DIR) tools
	sunxi-tools/fex2bin sunxi-boards/sys_config/$(SOC)/$(BOARD).fex > $(OUTPUT_DIR)/$(BOARD).bin

boot.scr: $(OUTPUT_DIR)
	@echo TODO boot.scr

$(OUTPUT_DIR):
	mkdir $(OUTPUT_DIR)

hwpack: u-boot boot.scr script.bin linux
	@echo WIP hwpack
	@mkdir -p $(OUTPUT_DIR)/rootfs

	@## Only support Debian/Ubuntu for now
	@#cp a10-config/rootfs/debian-ubuntu/* $(OUTPUT_DIR)/rootfs -rf

	@## bins
	@mkdir -p $(OUTPUT_DIR)/rootfs/usr/bin
	@#cp ../../a10-tools/a1x-initramfs.sh $(OUTPUT_DIR)/rootfs/usr/bin
	@#chmod 755 $(OUTPUT_DIR)/rootfs/usr/bin/a1x-initramfs.sh

	@## libs
	@mkdir -p $(OUTPUT_DIR)/rootfs/bin-backup
	@cp mali-libs/r2p4/armhf/x11/* $(OUTPUT_DIR)/rootfs -rf
	@cp mali-libs/r2p4/armhf/x11/* $(OUTPUT_DIR)/rootfs/bin-backup -rf

	@## kernel
	@mkdir -p $(OUTPUT_DIR)/kernel
	@cp linux-sunxi/$(O_PATH)/arch/arm/boot/uImage $(OUTPUT_DIR)/kernel/
	@cp $(OUTPUT_DIR)/$(BOARD).bin $(OUTPUT_DIR)/kernel/
	@#cp $(OUTPUT_DIR)/$(BOARD).scr $(OUTPUT_DIR)/kernel/boot.scr

	@## kernel modules
	@cp linux-sunxi/$(O_PATH)/output/lib $(OUTPUT_DIR)/rootfs/lib -rf

	@## bootloader
	@mkdir -p $(OUTPUT_DIR)/bootloader
	@cp u-boot-sunxi/spl/sunxi-spl.bin $(OUTPUT_DIR)/bootloader/
	@cp u-boot-sunxi/u-boot.bin $(OUTPUT_DIR)/bootloader/

	@## compress hwpack
	@7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../$(BOARD)_hwpack.7z $(OUTPUT_DIR)

include chosen_board.mk
