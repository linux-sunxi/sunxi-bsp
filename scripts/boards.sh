#!/bin/sh

set -e
if [ ! -d sunxi-boards/sys_config/ ]; then
	git submodule init
	git submodule update sunxi-boards
fi

generate_boards_mk() {
	echo "BOARDS = \\"

	ls -1 sunxi-boards/sys_config/*/*.fex |
	sed -n -e 's|.*/\([^/]\+\)\.fex$|\1|p' | sort -V |
	sed -e 's|.*|\t\0 \0-android \\|'

	cat <<EOT


\$(BOARDS):
	\$(SHELL) scripts/boards.sh \$@
EOT
}

# keep the output `sh` friendly
# i.e., no spaces around the '='
generate_chosen_board_mk() {
	local board="${1%-android}" android= soc=

	[ "$board" = "$1" ] || android=yes
	soc=$(ls -1 sunxi-boards/sys_config/*/$board.fex 2> /dev/null | cut -d/ -f3)

	cat <<-EOT
	BOARD=$board
	ANDROID=$android
	SOC=$soc
	UBOOT_CONFIG=$board
	EOT

	if [ "$soc" = a10 ]; then
		echo "KERNEL_CONFIG=sun4i${android:+_crane}_defconfig"
	else
		echo "KERNEL_CONFIG=a13${android:+_nuclear}_defconfig"
	fi
}

if [ $# -eq 0 ]; then
	out=board.mk
	generate_boards_mk > $out~
elif ls -1 sunxi-boards/sys_config/*/${1%-android}.fex 2> /dev/null 1>&2; then
	out=chosen_board.mk
	generate_chosen_board_mk $1 > $out~
else
	echo "$1: invalid board name" >&2
	exit 1
fi
mv $out~ $out
