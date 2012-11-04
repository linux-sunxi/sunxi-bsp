[ -s "./chosen_board.mk" ] || die "please run ./configure first."

#set -e

. ./chosen_board.mk

DRAGON=${PWD}/allwinner-tools/dragon/dragon
FSBUILD=${PWD}/allwinner-tools/fsbuild/fsbuild
BINS=${PWD}/allwinner-tools/bins
LIVESUIT_DIR=${PWD}/allwinner-tools/livesuit
CONFIGS_DIR=${LIVESUIT_DIR}/configs
SUNXI_TOOLS=${PWD}/sunxi-tools

modify_image_cfg()
{
	echo "Modifying image.cfg"
#    sed -i 's/imagename/;imagename/g' image.cfg

#    if [ $PACK_DEBUG = card0 ]; then
#        IMG_NAME="${PACK_CHIP}_${PACK_PLATFORM}_${PACK_BOARD}_$PACK_DEBUG.img"
#    else
#        IMG_NAME="${PACK_CHIP}_${PACK_PLATFORM}_${PACK_BOARD}.img"
#    fi
#    echo "imagename = $IMG_NAME" >> image.cfg
#    echo "" >> image.cfg
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


#    busybox unix2dos sys_config1.fex
#    busybox unix2dos sys_config.fex
	${BINS}/script ${LIVESUIT_DIR}/default/sys_config.fex
	${SUNXI_TOOLS}/fex2bin sunxi-boards/sys_config/${SOC}/${BOARD}.fex > ${CONFIGS_DIR}/sys_config1.bin
	${BINS}/update_23 ${CONFIGS_DIR}/sys_config1.bin ${CONFIGS_DIR}/boot0.bin ${CONFIGS_DIR}/boot1.bin
	${BINS}/update_23 ${CONFIGS_DIR}/sys_config1.bin ${CONFIGS_DIR}/card_boot0.fex ${CONFIGS_DIR}/card_boot1.fex SDMMC_CARD


	${BINS}/update_mbr ${CONFIGS_DIR}/sys_config.bin ${CONFIGS_DIR}/mbr.fex 4 16777216
	${FSBUILD} ${CONFIGS_DIR}/bootfs.ini ${CONFIGS_DIR}/split_xxxx.fex
	mv bootfs.fex ${CONFIGS_DIR}/bootloader.fex

#    # get env.fex
	${BINS}/u_boot_env_gen ${LIVESUIT_DIR}/default/env.cfg ${CONFIGS_DIR}/env.fex

#    # get the boot.img
#    ln -s $LICHEE_OUT/boot.img ${CONFIGS_DIR}/boot.fex

#    # get the rootfs
#    ln -s $LICHEE_OUT/rootfs.ext4 ${CONFIGS_DIR}/rootfs.fex

#	do_addchecksum


    ${DRAGON} ${LIVESUIT_DIR}/image.cfg

    if [ -e ${IMG_NAME} ]; then
        echo '---------' ${IMG_NAME} ' done-------------'
    fi

}

do_addchecksum()
{
	echo "do_addchecksum"
	# checksum for all fex (for android)
	${BINS}/FileAddSum ${CONFIGS_DIR}/bootloader.fex ${CONFIGS_DIR}/vbootloader.fex
	${BINS}/FileAddSum ${CONFIGS_DIR}/env.fex ${CONFIGS_DIR}/venv.fex
	${BINS}/FileAddSum ${CONFIGS_DIR}/boot.fex ${CONFIGS_DIR}/vboot.fex
	${BINS}/FileAddSum ${CONFIGS_DIR}/system.fex ${CONFIGS_DIR}/vsystem.fex
	${BINS}/FileAddSum ${CONFIGS_DIR}/recovery.fex ${CONFIGS_DIR}/vrecovery.fex
}

do_make_boot_img()
{
	echo "Make android boot image"
	${BINS}/mkbootimg --kernel bImage \
		--ramdisk rootfs.cpio.gz \
		--board 'cubieboard' \
		--base 0x40000000 \
		-o boot.img

}

do_pack_linux
