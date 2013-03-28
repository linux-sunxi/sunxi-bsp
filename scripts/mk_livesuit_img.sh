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
	echo "Modifying image.cfg: $1"
	cp -rf $1 ${BUILD_DIR}/image.cfg
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
	echo "Make bootfs: $1"
	cp -rf ${SOURCE_DIR}/eFex/split_xxxx.fex  ${BUILD_DIR}
 	cp -rf ${SOURCE_DIR}/eFex/card/mbr.fex  ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/bootfs ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/bootfs.ini ${BUILD_DIR}
	cp -rf ${SOURCE_DIR}/wboot/diskfs.fex ${BUILD_DIR}

	sed -i -e "s|^fsname=..*$|fsname=${BUILD_DIR}/bootloader.fex|g" \
		-e "s|^root0=..*$|root0=${BUILD_DIR}/bootfs|g" ${BUILD_DIR}/bootfs.ini

	# get env.fex
	${BINS}/u_boot_env_gen $1 ${BUILD_DIR}/env.fex

	# u-boot
	${SUNXI_TOOLS}/fex2bin ${BUILD_DIR}/sys_config1.fex > ${BUILD_DIR}/bootfs/script0.bin
	${SUNXI_TOOLS}/fex2bin ${BUILD_DIR}/sys_config1.fex > ${BUILD_DIR}/bootfs/script.bin

	# other
	mkdir -pv ${BUILD_DIR}/bootfs/vendor/system/media
	echo "empty" > ${BUILD_DIR}/bootfs/vendor/system/media/vendor

	if [ $ANDROID = false ]; then
		echo "Copying linux kernel and modules"
		cp -r ./build/${KERNEL_CONFIG}-linux/arch/arm/boot/uImage ${BUILD_DIR}/bootfs/
		cp -r ./build/${KERNEL_CONFIG}-linux/output/lib/modules ${BUILD_DIR}/bootfs/lib/
		rm -f ${BUILD_DIR}/bootfs/lib/modules/*/source
		rm -f ${BUILD_DIR}/bootfs/lib/modules/*/build
	fi

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
	echo "Make sys configs: $1"
	cp $1 ${BUILD_DIR}/sys_config.fex
	${BINS}/script ${BUILD_DIR}/sys_config.fex

	cp sunxi-boards/sys_config/${SOC}/${BOARD}.fex ${BUILD_DIR}/sys_config1.fex
	${SUNXI_TOOLS}/fex2bin ${BUILD_DIR}/sys_config1.fex > ${BUILD_DIR}/sys_config1.bin

}

cp_android_files()
{
	cp -rf $RECOVERY ${BUILD_DIR}/recovery.fex
	cp -rf $BOOT ${BUILD_DIR}/boot.fex
	cp -rf $SYSTEM ${BUILD_DIR}/system.fex

}

do_pack()
{
	echo "!!!Packing!!!\n"

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
	if [ $ANDROID = true ]; then
		make_sys_configs ${SOURCE_DIR}/default/sys_config_android.fex
		make_boot0_boot1
		make_bootfs ${SOURCE_DIR}/default/env_android.cfg
		modify_image_cfg ${SOURCE_DIR}/default/image_android.cfg
		cp_android_files
		do_addchecksum
	else
		make_sys_configs ${SOURCE_DIR}/default/sys_config_linux.fex
		make_boot0_boot1
		make_bootfs ${SOURCE_DIR}/default/env_linux.cfg
		cp "$ROOTFS" ${BUILD_DIR}/rootfs.fex
		modify_image_cfg ${SOURCE_DIR}/default/image_linux.cfg
	fi

	echo "Generating image"
	${DRAGON} ${BUILD_DIR}/image.cfg
	rm -rf ${BUILD_DIR}
	echo "Done"
}

while getopts R:r:b:s: opt; do
	case "$opt" in
		R) ROOTFS=$(readlink -f "$OPTARG"); ANDROID=false ;;
		r) RECOVERY=$(readlink -f "$OPTARG") ;;
		b) BOOT=$(readlink -f "$OPTARG") ;;
		s) SYSTEM=$(readlink -f "$OPTARG") ;;
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

do_pack



