.PHONY: all clean help
.PHONY: boards tools
.PHONY: submodule-init %-update u-boot linux

CROSS_COMPILER=arm-linux-gnueabihf-
OUTPUT_DIR=output

default: help

help:
	@echo Supported targets:
	@echo $(BOARDS)
	@echo
	@echo After choosing a target the following are also supported:
	@echo u-boot linux


all: tools

clean:
	rm -f boards.mk
	rm -f chosen_board.mk

tools: sunxi-tools-update
	$(MAKE) -C sunxi-tools

boards boards.mk:
	@$(SHELL) scripts/boards.sh

submodule-init:
	git submodule init

%-update: submodule-init
	git submodule update $*

u-boot: u-boot-sunxi-update
	$(MAKE) -C u-boot-sunxi $(UBOOT_CONFIG) CROSS_COMPILE=${CROSS_COMPILER}

O_PATH=build/linux-$(KERNEL_CONFIG)
linux: linux-sunxi-update
	$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm $(KERNEL_CONFIG)
	$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} uImage
	$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} INSTALL_MOD_PATH=$(O_PATH) modules
	$(MAKE) -C linux-sunxi O=$(O_PATH) ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} INSTALL_MOD_PATH=$(O_PATH) modules_install

script.bin: $(OUTPUT_DIR) tools
	sunxi-tools/fex2bin sunxi-boards/sys_config/$(SOC)/$(BOARD).fex > $(OUTPUT_DIR)/$(BOARD).bin

boot.scr: $(OUTPUT_DIR)
	@echo TODO boot.scr

$(OUTPUT_DIR):
	mkdir $(OUTPUT_DIR)

hwpack: u-boot boot.scr script.bin linux
	@echo TODO hwpack

-include board.mk
-include chosen_board.mk
