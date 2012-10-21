.PHONY: all clean help
.PHONY: tools
.PHONY: submodule-init %-update u-boot linux

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
	@echo TODO hwpack

include chosen_board.mk
