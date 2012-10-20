.PHONY: all clean help
.PHONY: boards tools

default: help

help:
	@echo Supported targets:
	@echo $(BOARDS)

all: tools

clean:
	rm -f boards.mk

tools: sunxi-tools/Makefile
	$(MAKE) -C sunxi-tools

boards boards.mk:
	@$(SHELL) scripts/boards.sh

sunxi-tools/Makefile:
	git submodule init
	git submodule update sunxi-tools

-include boards.mk
