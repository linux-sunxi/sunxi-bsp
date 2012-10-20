.PHONY: all clean tools

default: help

help:
	@echo Supported targets:
	@echo $(BOARDS)

all:

clean:
	rm -f boards.mk

tools: sunxi-tools/Makefile
	$(MAKE) -C sunxi-tools

boards.mk: scripts/boards.sh
	@$(SHELL) $^

sunxi-tools/Makefile:
	git submodule init
	git submodule update sunxi-tools

include boards.mk
