.PHONY: all clean help
.PHONY: boards tools

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

-include boards.mk
