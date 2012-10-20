#!/bin/sh

set -e
if [ ! -d sunxi-boards/sys_config/ ]; then
	git submodule init
	git submodule update sunxi-boards
fi

BOARDS=$(ls -1 sunxi-boards/sys_config/*/*.fex |
	sed -n -e 's|.*/\([^/]\+\)\.fex$|\1\n\1-android|p' |
	sort | tr '\n' ' ')

cat <<EOT > boards.mk~
BOARDS=$BOARDS

\$(BOARDS):
	\$(SHELL) scripts/boards.sh $<
EOT
mv boards.mk~ boards.mk
