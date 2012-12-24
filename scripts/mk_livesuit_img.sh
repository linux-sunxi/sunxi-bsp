die() {
	echo "$*" >&2
	exit 1
}

[ -s "./chosen_board.mk" ] || die "please run ./configure first."

set -e

. ./chosen_board.mk

DRAGON=${PWD}/allwinner-tools/dragon/dragon
FSBUILD=${PWD}/allwinner-tools/fsbuild/fsbuild
BINS=${PWD}/allwinner-tools/bins
LIVESUIT_DIR=${PWD}/allwinner-tools/livesuit
SOURCE_DIR=${LIVESUIT_DIR}/${SOC}
BUILD_DIR=${PWD}/build/${BOARD}_livesuit
BUILD_DIR_LOCAL=build/${BOARD}_livesuit
SUNXI_TOOLS=${PWD}/sunxi-tools
ROOTFS=
RECOVERY=
BOOT=
SYSTEM=
ANDROID=true

show_usage_and_die()
{
	echo "Usage (linux): $0 -R [rootfs.tar.gz]"
	echo "Usage (android): $0 -b [boot.img] -s [system.img] -r [recovery.img]"
	exit 1
}

modify_image_cfg()
{
	echo "Modifying image.cfg"
	if [ $ANDROID = true ]; then
		cp -rf ${SOURCE_DIR}/default/image_android.cfg ${BUILD_DIR}/image.cfg
	else
		cp -rf ${SOURCE_DIR}/default/image_linux.cfg ${BUILD_DIR}/image.cfg
	fi
	sed -i -e "s|^INPUT_DIR..*$|INPUT_DIR=${BUILD_DIR}|g" \
		-e "s|^EFEX_DIR..*$|EFEX_DIR=${SOURCE_DIR}/eFex|g" \
		-e "s|^imagename..*$|imagename=output/${BOARD}_livesuit.img|g" \
		${BUILD_DIR}/image.cfg
}



do_addchecksum()
{
	echo "Add checksum"
	# checksum for all fex (for android)
	${BINS}/FileAddSum ${BUILD_DIR}/bootloader.fex ${BUILD_DIR}/vbootloader.fex
	${BINS}/FileAddSum ${BUILD_DIR}/env.fex ${BUILD_DIR}/venv.fex
	${BINS}/FileAddSum ${BUILD_DIR}/boot.fex ${BUILD_DIR}/vboot.fex
	${BINS}/FileAddSum ${BUILD_DIR}/system.fex ${BUILD_DIR}/vsystem.fex
	${BINS}/FileAddSum ${BUILD_DIR}/recovery.fex ${BUILD_DIR}/vrecovery.fex
}

make_bootfs()
{
	echo "Make bootfs"
	cp -rf ${SOURCE_DIR}/eFex/split_xxxx.fex  ${BUILD_DIR}
 	cp -rf ${SOURCE_DIR}/eFex/card/mbr.fex  ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/bootfs ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/bootfs.ini ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/diskfs.fex ${BUILD_DIR}

	sed -i -e "s|^fsname=..*$|fsname=${BUILD_DIR}/bootloader.fex|g" \
		-e "s|^root0=..*$|root0=${BUILD_DIR}/bootfs|g" ${BUILD_DIR}/bootfs.ini

	# get env.fex
	${BINS}/u_boot_env_gen ${SOURCE_DIR}/default/env.cfg ${BUILD_DIR}/env.fex

	# u-boot
	${SUNXI_TOOLS}/fex2bin ${BUILD_DIR}/sys_config1.fex > ${BUILD_DIR}/bootfs/script0.bin
	${SUNXI_TOOLS}/fex2bin ${BUILD_DIR}/sys_config1.fex > ${BUILD_DIR}/bootfs/script.bin

	# other
	mkdir -pv ${BUILD_DIR}/bootfs/vendor/system/media
	echo "empty" > ${BUILD_DIR}/bootfs/vendor/system/media/vendor

	# build
	${BINS}/update_mbr ${BUILD_DIR}/sys_config.bin ${BUILD_DIR}/mbr.fex 4 16777216
	${FSBUILD} ${BUILD_DIR}/bootfs.ini ${BUILD_DIR}/split_xxxx.fex
}

make_boot0_boot1()
{
	echo "Make boot0 boot1"
	cp -rf ${SOURCE_DIR}/eGon/storage_media/nand/boot0.bin ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/eGon/storage_media/nand/boot1.bin ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/eGon/storage_media/sdcard/boot0.bin ${BUILD_DIR}/card_boot0.fex
	cp -rf ${SOURCE_DIR}/eGon/storage_media/sdcard/boot1.bin ${BUILD_DIR}/card_boot1.fex

	${BINS}/update_23 ${BUILD_DIR_LOCAL}/sys_config1.bin ${BUILD_DIR_LOCAL}/boot0.bin ${BUILD_DIR_LOCAL}/boot1.bin
	${BINS}/update_23 ${BUILD_DIR_LOCAL}/sys_config1.bin ${BUILD_DIR_LOCAL}/card_boot0.fex ${BUILD_DIR_LOCAL}/card_boot1.fex SDMMC_CARD
}

make_sys_configs()
{
	echo "Make sys configs"
	#busybox unix2dos sys_config1.fex
	#busybox unix2dos sys_config.fex
	if [ $ANDROID = true ]; then
		cp ${SOURCE_DIR}/default/sys_config_android.fex ${BUILD_DIR}/sys_config.fex
	else
		cp ${SOURCE_DIR}/default/sys_config_linux.fex ${BUILD_DIR}/sys_config.fex
	fi
	${BINS}/script ${BUILD_DIR}/sys_config.fex

	cp sunxi-boards/sys_config/${SOC}/${BOARD}.fex ${BUILD_DIR}/sys_config1.fex
	${SUNXI_TOOLS}/fex2bin ${BUILD_DIR}/sys_config1.fex > ${BUILD_DIR}/sys_config1.bin

}

make_boot_img()
{
	echo "Make android boot image"
	${BINS}/mkbootimg --kernel ./build/${KERNEL_CONFIG}-linux/bImage \
		--ramdisk ./linux-sunxi/rootfs/sun4i_rootfs.cpio.gz \
		--board ${BOARD} \
		--base 0x40000000 \
		-o ${BUILD_DIR}/boot.fex
}

cp_android_files()
{
	cp -rf $RECOVERY ${BUILD_DIR}/recovery.fex
	cp -rf $BOOT ${BUILD_DIR}/boot.fex
	cp -rf $SYSTEM ${BUILD_DIR}/system.fex

}

do_pack_linux()
{
    echo "!!!Packing for linux!!!\n"

#    if [ $PACK_CHIP = sun4i ]; then
#	if [ $PACK_DEBUG = card0 ]; then
#	    cp $TOOLS_DIR/awk_debug_card0 out/awk_debug_card0
#	    TX=`awk  '$0~"a10"{print $2}' pctools/linux/card_debug_pin`
#	    RX=`awk  '$0~"a10"{print $3}' pctools/linux/card_debug_pin`
#	    sed -i s'/uart_debug_tx =/uart_debug_tx = '$TX'/g' out/awk_debug_card0
#	    sed -i s'/uart_debug_rx =/uart_debug_rx = '$RX'/g' out/awk_debug_card0
#	    sed -i s'/uart_tx =/uart_tx = '$TX'/g' out/awk_debug_card0
#	    sed -i s'/uart_rx =/uart_rx = '$RX'/g' out/awk_debug_card0
#	    awk -f out/awk_debug_card0 out/sys_config1.fex > out/a.fex
#	    rm out/sys_config1.fex
#	    mv out/a.fex out/sys_config1.fex
#	    echo "uart -> card0 !!!"
#	fi
#    fi
	mkdir -p ${BUILD_DIR}
	make_sys_configs
	make_boot0_boot1
	make_bootfs
	make_boot_img
	modify_image_cfg
	if [ $ANDROID = true ]; then
		cp_android_files
		do_addchecksum
	fi

	echo "Generating image"
	${DRAGON} ${BUILD_DIR}/image.cfg
}

while getopts R:r:b:s: opt; do
    case "$opt" in
	R)	ROOTFS="$OPTARG"; ANDROID=false ;;
	r)	RECOVERY="$OPTARG" ;;
	b)	BOOT="$OPTARG" ;;
	s)	SYSTEM="$OPTARG" ;;
	:) show_usage_and_die ;;
	*) show_usage_and_die ;;
    esac
done

if [ $ANDROID = true ]; then
	[ -e "$RECOVERY" ] || show_usage_and_die
	[ -e "$BOOT" ] || show_usage_and_die
	[ -e "$SYSTEM" ] || show_usage_and_die
else
	[ -e "$ROOTFS" ] || show_usage_and_die
fi

do_pack_linux



