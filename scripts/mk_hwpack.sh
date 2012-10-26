#!/bin/sh

U_O_PATH=$1
K_O_PATH=$2
OUTPUT_DIR=$3
BOARD=$4

echo WIP hwpack
mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack
mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs

## Only support Debian/Ubuntu for now
#cp a10-config/rootfs/debian-ubuntu/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs -rf

## bins
mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin
#cp ../../a10-tools/a1x-initramfs.sh ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin
#chmod 755 ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/usr/bin/a1x-initramfs.sh

## libs
mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/bin-backup
cp mali-libs/r2p4/armhf/x11/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs -rf
cp mali-libs/r2p4/armhf/x11/* ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/bin-backup -rf

## kernel
mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/kernel
cp ${K_O_PATH}/arch/arm/boot/uImage ${OUTPUT_DIR}/${BOARD}_hwpack/kernel/
cp ${OUTPUT_DIR}/${BOARD}.bin ${OUTPUT_DIR}/${BOARD}_hwpack/kernel/
## boot.scr (optional)
cp ${OUTPUT_DIR}/boot.scr ${OUTPUT_DIR}/${BOARD}_hwpack/kernel/boot.scr

## kernel modules
cp -a ${K_O_PATH}/output/lib/modules ${OUTPUT_DIR}/${BOARD}_hwpack/rootfs/lib

## bootloader
mkdir -p ${OUTPUT_DIR}/${BOARD}_hwpack/bootloader
cp ${U_O_PATH}/spl/sunxi-spl.bin ${OUTPUT_DIR}/${BOARD}_hwpack/bootloader/
cp ${U_O_PATH}/u-boot.bin ${OUTPUT_DIR}/${BOARD}_hwpack/bootloader/

## compress hwpack
cd ${OUTPUT_DIR}/${BOARD}_hwpack/ && 7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../${BOARD}_hwpack.7z .

