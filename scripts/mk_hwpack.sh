#!/bin/sh

die() {
	echo "$*" >&2
	exit 1
}

[ -s "./chosen_board.mk" ] || die "please run ./configure first."

set -e

. ./chosen_board.mk

U_O_PATH="build/u-boot-$UBOOT_CONFIG"
K_O_PATH="build/linux-$KERNEL_CONFIG"

OUTPUT_DIR="output"
HWPACK_DIR="$OUTPUT_DIR/${BOARD}_hwpack"

ABI=armhf
MALI=r3p0

cp_debian_files() {
	local rootfs="$1" malidir="mali-libs/$MALI/$ABI/x11"

	echo "Debian/Ubuntu hwpack"
	#cp a10-config/rootfs/debian-ubuntu/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs -rf

	## libs
	mkdir -p "$rootfs/bin-backup"
	cp -rf "$malidir"/* "$rootfs/"
	cp -rf "$malidir"/* "$rootfs/bin-backup/"
}

cp_android_files() {
	local rootfs="$1" malidir="mali-libs/$MALI/armel/android"

	echo "Android hwpack"

	## libs
	mkdir -p "${rootfs}/bin-backup"
	cp -rf "$malidir"/* "$rootfs/"
	cp -rf "$malidir"/* "$rootfs/bin-backup/"
}

create_hwpack() {
	local hwpack="$1"
	local rootfs="$HWPACK_DIR/rootfs"
	local kerneldir="$HWPACK_DIR/kernel"
	local bootloader="$HWPACK_DIR/bootloader"

	mkdir -p "$rootfs/usr/bin" "$rootfs/lib"

	if [ -z "$ANDROID" ]; then
		cp_debian_files "$rootfs"
	else
		cp_android_files "$rootfs"
	fi

	## bins
	#cp ../../a10-tools/a1x-initramfs.sh ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin
	#chmod 755 ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin/a1x-initramfs.sh

	## kernel
	mkdir -p "$kerneldir"
	cp "$K_O_PATH"/arch/arm/boot/uImage "$kerneldir/"
	cp "build/$BOARD.bin" "$kerneldir/script.bin"

	## boot.scr (optional)
	cp "build/boot.scr" "$kerneldir/boot.scr" || true

	## kernel modules
	cp -a "$K_O_PATH/output/lib/modules" "${rootfs}/lib/"

	## bootloader
	mkdir -p "$bootloader"
	cp "$U_O_PATH/spl/sunxi-spl.bin" "$bootloader/"
	cp "$U_O_PATH/u-boot.bin" "$bootloader/"

	## compress hwpack
	cd "$HWPACK_DIR"
	7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on "$hwpack" .
	cd - > /dev/null
}

create_hwpack "../${BOARD}_hwpack.7z"
