#!/bin/sh

U_O_PATH=$1
K_O_PATH=$2
OUTPUT_DIR=$3
BOARD=$4

try ()
{
	#
	# Execute the command and fail if it does not return zero.
	#
	eval ${*} || exit 1
}

create_hwpack() {
	echo WIP hwpack
	try mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack
	try mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs

	## Only support Debian/Ubuntu for now
	#cp a10-config/rootfs/debian-ubuntu/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs -rf

	## bins
	try mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin
	#cp ../../a10-tools/a1x-initramfs.sh ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin
	#chmod 755 ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin/a1x-initramfs.sh

	## libs
	try mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/bin-backup
	try cp mali-libs/r2p4/armhf/x11/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs -rf
	try cp mali-libs/r2p4/armhf/x11/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/bin-backup -rf

	## kernel
	try mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/kernel
	try cp ${K_O_PATH}/arch/arm/boot/uImage ${OUTPUT_DIR}/${BOARD}_hwpack/kernel/
	try cp ${OUTPUT_DIR}/${BOARD}.bin ${OUTPUT_DIR}/${BOARD}_hwpack/kernel/
	## boot.scr (optional)
	try cp ${OUTPUT_DIR}/boot.scr ${OUTPUT_DIR}/${BOARD}_hwpack/kernel/boot.scr

	## kernel modules
	try cp -a ${K_O_PATH}/output/lib/modules ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/lib

	## bootloader
	try mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/bootloader
	try cp ${U_O_PATH}/spl/sunxi-spl.bin ${OUTPUT_DIR}/${BOARD}_hwpack/bootloader/
	try cp ${U_O_PATH}/u-boot.bin ${OUTPUT_DIR}/${BOARD}_hwpack/bootloader/

	## compress hwpack
	try cd ${OUTPUT_DIR}/${BOARD}_hwpack/ && 7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../${BOARD}_hwpack.7z .
}

if [ -z $4 ]; then
	echo "usage \"mk_hwpack.sh u-boot-path linux-path output-dir board\""
	exit 1
else
	try create_hwpack
fi

