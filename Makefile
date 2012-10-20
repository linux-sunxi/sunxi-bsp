.PHONY: all clean help
.PHONY: boards tools
.PHONY: submodule-init %-update u-boot linux

cross_compiler=arm-linux-gnueabihf-

default: help

help:
	@echo Supported targets:
	@echo $(BOARDS)

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
	$(MAKE) -C u-boot-sunxi $(BOARD) CROSS_COMPILE=arm-linux-gnueabi-

linux: linux-sunxi-update
	$(MAKE) -C linux-sunxi ARCH=arm $(KERNEL_CONFIG)
	$(MAKE) -C linux-sunxi ARCH=arm CROSS_COMPILE=${cross_compiler} uImage
	$(MAKE) -C linux-sunxi ARCH=arm CROSS_COMPILE=${cross_compiler} INSTALL_MOD_PATH=output modules
	$(MAKE) -C linux-sunxi ARCH=arm CROSS_COMPILE=${cross_compiler} INSTALL_MOD_PATH=output modules_install

-include board.mk
-include chosen_board.mk
