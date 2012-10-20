#!/bin/sh

set -e
if [ ! -d sunxi-boards/sys_config/ ]; then
	git submodule init
	git submodule update sunxi-boards
fi

boards() {
	ls -1 sunxi-boards/sys_config/*/*.fex |
	sed -n -e 's|.*/\([^/]\+\)\.fex$|\1|p' | sort -V |
	sed -e 's|.*|\t\0 \0-android \\|'
}

cat <<EOT > boards.mk~
BOARDS= \\
$(boards)


\$(BOARDS):
	\$(SHELL) scripts/boards.sh \$@
EOT
mv boards.mk~ boards.mk
