#!/bin/sh

die() {
	echo "$*" >&2
	exit 1
}

[ -s "./chosen_board.mk" ] || die "please run ./configure first."

set -e

. ./chosen_board.mk

U_O_PATH="build/$UBOOT_CONFIG-u-boot"
K_O_PATH="build/$KERNEL_CONFIG-linux"
HWPACK_DIR="build/${BOARD}_hwpack"

ABI=armhf

cp_debian_files() {
	local rootfs="$1"
	local cedarxdir="cedarx-libs/libcedarv/linux-$ABI"
	local libtype="x11" # or framebuffer
	local x= y=

	echo "Debian/Ubuntu hwpack"
	cp -r "rootfs/debian-ubuntu"/* "$rootfs/"

	## libs
	install -m 0755 $(find "$cedarxdir" -name '*.so') "$rootfs/lib/"

	## kernel modules
	cp -r "$K_O_PATH/output/lib/modules" "$rootfs/lib/"
	rm -f "$rootfs/lib/modules"/*/source
	rm -f "$rootfs/lib/modules"/*/build

	## bins
	#cp ../../a10-tools/a1x-initramfs.sh ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin
	#chmod 755 ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin/a1x-initramfs.sh
}

cp_android_files() {
	local rootfs="$1" f=

	echo "Android hwpack"

	mkdir -p "${rootfs}/boot"
	## kernel
	cp -r "$K_O_PATH"/arch/arm/boot/uImage "${rootfs}/boot/"
	cp -r "build/$BOARD.bin" "${rootfs}/boot/script.bin"

	## kernel modules
	mkdir -p "$rootfs/system/lib/modules"
	find "$K_O_PATH/output/lib/modules" -name "*.ko"  -print0 |xargs -0 cp -t "$rootfs/system/lib/modules/"

	## boot scripts (optional)
	for f in boot.scr uEnv.txt; do
		if [ -s "build/$f" ]; then
			cp "build/$f" "$rootfs/boot/"
		fi
	done
}

create_hwpack() {
	local hwpack="$1"
	local rootfs="$HWPACK_DIR/rootfs"
	local kerneldir="$HWPACK_DIR/kernel"
	local bootloader="$HWPACK_DIR/bootloader"
	local f=

	rm -rf "$HWPACK_DIR"

	mkdir -p "$rootfs/usr/bin" "$rootfs/lib"

	if [ -z "$ANDROID" ]; then
		cp_debian_files "$rootfs"
	else
		cp_android_files "$rootfs"
	fi

	## kernel
	mkdir -p "$kerneldir"
	cp -r "$K_O_PATH"/arch/arm/boot/uImage "$kerneldir/"
	cp -r "build/$BOARD.bin" "$kerneldir/script.bin"

	## boot scripts (optional)
	for f in boot.scr uEnv.txt; do
		if [ -s "build/$f" ]; then
			cp "build/$f" "$kerneldir/"
		fi
	done

	## bootloader
	mkdir -p "$bootloader"
	cp -r "$U_O_PATH/spl/sunxi-spl.bin" "$bootloader/"
	cp -r "$U_O_PATH/u-boot.bin" "$bootloader/"

	## compress hwpack
	cd "$HWPACK_DIR"
	case "$hwpack" in
	*.7z)
		7z u -up1q0r2x1y2z1w2 -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on "$hwpack" .
		;;
	*.tar.bz2)
		find . ! -type d | cut -c3- | sort -V | tar -jcf "$hwpack" -T -
		;;
	*.tar.xz)
		find . ! -type d | cut -c3- | sort -V | tar -Jcf "$hwpack" -T -
		;;
	*)
		die "Not supported hwpack format"
		;;
	esac
	cd - > /dev/null
	echo "Done."
}

[ $# -eq 1 ] || die "Usage: $0 <hwpack.7z>"

create_hwpack "$1"
