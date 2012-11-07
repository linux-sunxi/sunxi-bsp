die() {
	echo "$*" >&2
	exit 1
}

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
	cp -rf ${LIVESUIT_DIR}/${SOC}/default/image.cfg ${CONFIGS_DIR}
	sed -i -e "s|^INPUT_DIR..*$|INPUT_DIR=${CONFIGS_DIR}|g" \
		-e "s|^EFEX_DIR..*$|EFEX_DIR=${LIVESUIT_DIR}/${SOC}/eFex|g" ${CONFIGS_DIR}/image.cfg
#    sed -i 's/imagename/;imagename/g' image.cfg

#    if [ $PACK_DEBUG = card0 ]; then
#        IMG_NAME="${PACK_CHIP}_${PACK_PLATFORM}_${PACK_BOARD}_$PACK_DEBUG.img"
#    else
#        IMG_NAME="${PACK_CHIP}_${PACK_PLATFORM}_${PACK_BOARD}.img"
#    fi
#    echo "imagename = $IMG_NAME" >> image.cfg
#    echo "" >> image.cfg
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

make_bootfs()
{
	cp -rf ${LIVESUIT_DIR}/${SOC}/eFex/split_xxxx.fex  ${CONFIGS_DIR}
 	cp -rf ${LIVESUIT_DIR}/${SOC}/eFex/card/mbr.fex  ${CONFIGS_DIR}
	cp -rf ${LIVESUIT_DIR}/${SOC}/wboot/bootfs ${CONFIGS_DIR}
	cp -rf ${LIVESUIT_DIR}/${SOC}/wboot/bootfs.ini ${CONFIGS_DIR}
	cp -rf ${LIVESUIT_DIR}/${SOC}/wboot/diskfs.fex ${CONFIGS_DIR}

	sed -i -e "s|^fsname=..*$|fsname=${CONFIGS_DIR}/bootloader.fex|g" \
		-e "s|^root0=..*$|root0=${CONFIGS_DIR}/bootfs|g" ${CONFIGS_DIR}/bootfs.ini

	${BINS}/update_mbr ${CONFIGS_DIR}/sys_config.bin ${CONFIGS_DIR}/mbr.fex 4 16777216
	${FSBUILD} ${CONFIGS_DIR}/bootfs.ini ${CONFIGS_DIR}/split_xxxx.fex

	# get env.fex
	${BINS}/u_boot_env_gen ${LIVESUIT_DIR}/${SOC}/default/env.cfg ${CONFIGS_DIR}/env.fex
}

make_boot0_boot1()
{
	cp -rf ${LIVESUIT_DIR}/${SOC}/eGon/storage_media/nand/boot0.bin ${CONFIGS_DIR}
	cp -rf ${LIVESUIT_DIR}/${SOC}/eGon/storage_media/nand/boot1.bin ${CONFIGS_DIR}
	cp -rf ${LIVESUIT_DIR}/${SOC}/eGon/storage_media/sdcard/boot0.bin ${CONFIGS_DIR}/card_boot0.fex
	cp -rf ${LIVESUIT_DIR}/${SOC}/eGon/storage_media/sdcard/boot1.bin ${CONFIGS_DIR}/card_boot1.fex

	${BINS}/update_23 ${CONFIGS_DIR}/sys_config1.bin ${CONFIGS_DIR}/boot0.bin ${CONFIGS_DIR}/boot1.bin
	${BINS}/update_23 ${CONFIGS_DIR}/sys_config1.bin ${CONFIGS_DIR}/card_boot0.fex ${CONFIGS_DIR}/card_boot1.fex SDMMC_CARD
}

make_sys_configs()
{
	#busybox unix2dos sys_config1.fex
	#busybox unix2dos sys_config.fex
	cp ${LIVESUIT_DIR}/${SOC}/default/sys_config.fex ${CONFIGS_DIR}/sys_config.fex
	${BINS}/script ${CONFIGS_DIR}/sys_config.fex

	cp sunxi-boards/sys_config/${SOC}/${BOARD}.fex ${CONFIGS_DIR}/sys_config1.fex
	${SUNXI_TOOLS}/fex2bin ${CONFIGS_DIR}/sys_config1.fex > ${CONFIGS_DIR}/sys_config1.bin

}

make_boot_img()
{
	echo "Make android boot image"
	${BINS}/mkbootimg --kernel ./build/${KERNEL_CONFIG}-linux/bImage \
		--ramdisk ./linux-sunxi/rootfs/sun4i_rootfs.cpio.gz \
		--board 'cubieboard' \
		--base 0x40000000 \
		-o ${CONFIGS_DIR}/boot.fex
}


make_rootfs()
{
	local f=$(readlink -f "$1")
	local source=$PWD"/source_tmp"
	local target=$PWD"/target_tmp"

	echo "Make linux.ext4"
	mkdir -p $target
	rm -f linux.ext4
	dd if=/dev/zero of=linux.ext4 bs=1M count=1024
	mkfs.ext4 linux.ext4
	sudo mount linux.ext4 $target -o loop=/dev/loop0

	mkdir -p $source
	cd $source
	sudo tar xzf "$f"
	if [ -d $source/etc ]; then
		echo "Standard rootfs"
		sudo cp -a $source/* $target
	elif [ -d $source/binary/boot/filesystem.dir ]; then
		echo "Linaro rootfs"
		sudo cp -a $source/binary/boot/filesystem.dir/* $target
	else
		die "Unsupported rootfs"
	fi
	
	cd - > /dev/null
	sudo umount $target
	sudo sudo rm -rf $source
	sudo sudo rm -rf $target
	mv linux.ext4 ${CONFIGS_DIR}/rootfs.fex
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

	make_sys_configs
	make_boot0_boot1
	make_bootfs
	modify_image_cfg

	${DRAGON} ${CONFIGS_DIR}/image.cfg

	if [ -e ${IMG_NAME} ]; then
		echo '---------' ${IMG_NAME} ' done-------------'
	fi

}


#make_rootfs "$1"
#make_boot_img
do_pack_linux


