.PHONY: all clean

all:

clean:
	rm -f boards.mk

boards.mk: scripts/boards.sh
	$(SHELL) $^

include boards.mk
