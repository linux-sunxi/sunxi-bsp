.PHONY: all clean help
.PHONY: boards tools
.PHONY: submodule-init %-update %-u-boot-build


default: help

help:
	@echo Supported targets:
	@echo $(BOARDS)

all: tools

clean:
	rm -f boards.mk

tools: sunxi-tools-update
	$(MAKE) -C sunxi-tools

boards boards.mk:
	@$(SHELL) scripts/boards.sh

submodule-init:
	git submodule init

%-update: submodule-init
	git submodule update $*

%-u-boot-build: %-update
	$(MAKE) -C u-boot-sunxi $* CROSS_COMPILE=arm-linux-gnueabi-


-include boards.mk
