#!/bin/sh

. ./chosen_board.mk

U_O_PATH="$1"
K_O_PATH="$2"
OUTPUT_DIR="$3"

set -e

cp_debian_files() {
	echo "Debian/Ubuntu hwpack"
	#cp a10-config/rootfs/debian-ubuntu/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs -rf

	## libs
	mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/bin-backup
	cp mali-libs/r3p0/armhf/x11/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs -rf
	cp mali-libs/r3p0/armhf/x11/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/bin-backup -rf
}

cp_android_files() {
	echo "Android hwpack"

	## libs
	mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/bin-backup
	cp mali-libs/r3p0/armel/android/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs -rf
	cp mali-libs/r3p0/armel/android/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/bin-backup -rf
}

create_hwpack() {
	echo WIP hwpack
	mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack
	mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs

	if [ -z "${ANDROID}" ]; then
		cp_debian_files
	else
		cp_android_files
	fi

	## bins
	mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin
	#cp ../../a10-tools/a1x-initramfs.sh ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin
	#chmod 755 ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin/a1x-initramfs.sh

	## kernel
	mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/kernel
	cp ${K_O_PATH}/arch/arm/boot/uImage ${OUTPUT_DIR}/${BOARD}_hwpack/kernel/
	cp ${OUTPUT_DIR}/${BOARD}.bin ${OUTPUT_DIR}/${BOARD}_hwpack/kernel/
	## boot.scr (optional)
	cp ${OUTPUT_DIR}/boot.scr ${OUTPUT_DIR}/${BOARD}_hwpack/kernel/boot.scr || true

	## kernel modules
	cp -a ${K_O_PATH}/output/lib/modules ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/lib

	## bootloader
	mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/bootloader
	cp ${U_O_PATH}/spl/sunxi-spl.bin ${OUTPUT_DIR}/${BOARD}_hwpack/bootloader/
	cp ${U_O_PATH}/u-boot.bin ${OUTPUT_DIR}/${BOARD}_hwpack/bootloader/

	## compress hwpack
	( cd ${OUTPUT_DIR}/${BOARD}_hwpack/ && p7zip a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../${BOARD}_hwpack.7z . )
}

if [ $# -ne 3 ]; then
	echo "usage \"mk_hwpack.sh u-boot-path linux-path output-dir\""
	exit 1
fi
create_hwpack
