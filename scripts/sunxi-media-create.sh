#!/bin/bash
# Usage ./makeSD.sh /dev/sdx hwpack rootfs

hwpack_update_only=0

BOOT_SIZE=64

TEMP="${TMPDIR:-/tmp}/.sunxi-media-create.$$"
HWPACKDIR="$TEMP/hwpack"
ROOTFSDIR="$TEMP/rootfs"
MNTBOOT="$TEMP/mnt_boot"
MNTROOT="$TEMP/mnt_root"

cleanup() {
	local x=
	# umount card
	for x in $MNTBOOT $MNTROOT; do
		x=$(readlink -f "$x")
		if grep -q " $x " /proc/mounts; then
			sudo umount "$x" || exit 1
		fi
	done

	# and delete temporal files
	sudo rm -rf --one-file-system "$TEMP"
}

die() {
	echo "$*" >&2
	cleanup
	exit 1
}

title() {
	echo
	echo "==="
	echo "=== $* ==="
	echo "==="
}

checkSyntax () {
	if [ $# -lt 3 ]; then
		echo "Usage: $0 [device] [hwpack] [rootfs]"
                echo "Write norootfs for [rootfs] if you want to only update" 
                echo "u-boot, script.bin, the kernel and modules"
		exit 1
	fi

	[ -b "$1" ] || die "$1: Invalid device"
	[ -s "$2" ] || die "$2: Hardware pack not found"

        if [ "$3" = norootfs ]; then
		hwpack_update_only=1;
	elif [ ! -s "$3" ]; then
		die "$3: rootfs file not found"
        fi
}

umountSD () {
	local partlist=$(grep "^$1" /proc/mounts | cut -d' ' -f1)
	[ -z "$partlist" ] || sudo umount $partlist
}

partitionSD () {
	local dev="$1" subdevice=
	case "$dev" in
	*/mmcblk*|*/loop*)
		subdevice="${1}p"
		;;
	*)
		subdevice="$1"
		;;
	esac

	title "Partitioning $dev"
	sudo dd if=/dev/zero of="$dev" bs=1M count=1 ||
		die "$dev: failed to zero the first MB"

	sudo sfdisk -L -R "$dev" 2> /dev/null

	sudo sfdisk -L -uM "$dev" <<-EOT
	1,$BOOT_SIZE,c
	$(expr 1 + $BOOT_SIZE),,L
	EOT
	[ $? -eq 0 ] ||
		die "$dev: failed to repartition media"

	sleep 1
	sudo sfdisk -L -R "$dev" ||
		die "$dev: failed to reload media"

	title "Format Partition 1 to VFAT"
	sudo mkfs.vfat -I ${subdevice}1 ||
		die "${subdevice}1: failed to format partition"

	title "Format Partition 2 to EXT4"
	sudo mkfs.ext4  ${subdevice}2 ||
		die "${subdevice}2: failed to format partition"
}

extract() {
	local f=$(readlink -f "$1")
	title "Extracting $3"

	mkdir -p "$2"
	cd "$2"
	case "$f" in
	*.tar.bz2|*.tbz2)
		sudo tar xjf "$f"
		;;
	*.tar.gz|*.tgz)
		sudo tar xzf "$f"
		;;
	*.7z|*.lzma)
		sudo 7z x "$f"
		;;
	*.tar.xz)
		sudo tar xJf "$f"
		;;
	*)
		die "$f: unknown file extension"
		;;
	esac
	cd - > /dev/null
}

copyUbootSpl ()
{	
	sudo dd if=$2 bs=1024 of=$1 seek=8
}

copyUboot ()
{	
	sudo dd if=$2 bs=1024 of=$1 seek=32
}

mountPartitions ()
{
	local dev="$1" subdevice=
	case "$dev" in
	*/mmcblk*|*/loop*)
		subdevice="${1}p"
		;;
	*)
		subdevice="$1"
		;;
	esac

	mkdir -p "$MNTROOT" "$MNTBOOT" ||
		die "Failed to create SD card mount points"

	sudo mount ${subdevice}1 "$MNTBOOT" ||
		die "Failed to mount VFAT partition (SD)"

	sudo mount ${subdevice}2 "$MNTROOT" ||
		die "Failed to mount EXT4 partition (SD)"
}

copyData () 
{
	echo "Copy VFAT partition files to SD Card"
	sudo cp $HWPACKDIR/kernel/uImage $MNTBOOT ||
		die "Failed to copy VFAT partition data to SD Card"
	sudo cp $HWPACKDIR/kernel/*.bin $MNTBOOT/script.bin ||
		die "Failed to copy VFAT partition data to SD Card"
	if [ -s $HWPACKDIR/kernel/*.scr ]; then 
		sudo cp $HWPACKDIR/kernel/*.scr $MNTBOOT/boot.scr ||
			die "Failed to copy VFAT partition data to SD Card"
	fi
	 
        if [ ${hwpack_update_only} -eq 0 ]; then 
	    title "Copy rootfs partition files to SD Card"
            if [ -d $ROOTFSDIR/etc ]; then
               echo "Standard rootfs"
	       sudo cp -a $ROOTFSDIR/* $MNTROOT
            elif [ -d $ROOTFSDIR/binary/boot/filesystem.dir ]; then
               echo "Linaro rootfs"
	       sudo cp -a $ROOTFSDIR/binary/boot/filesystem.dir/* $MNTROOT
            else
               die "Unsupported rootfs"
            fi
        fi
	if [ $? -ne 0 ]; then
		die "Failed to copy rootfs partition data to SD Card"
	fi 

	title "Copy hwpack rootfs files"
	# Fedora uses a softlink for lib.  Adjust, if needed.
	if [ -L $MNTROOT/lib ]; then
		# Find where it points.  For Fedora, we expect usr/lib.
		DEST=`/bin/ls -l $MNTROOT/lib | sed -e 's,.* ,,'`
		if [ "$DEST" = "usr/lib" ]; then
			mv $ROOTFS/lib $ROOTFS/usr
		fi
	fi
        sudo cp -a $HWPACKDIR/rootfs/* $MNTROOT/ ||
		die "Failed to copy rootfs hwpack files to SD Card"
}

# "main"
checkSyntax $1 $2 $3
umountSD $1
if [ ${hwpack_update_only} -eq 0 ]; then 
    partitionSD $1 
fi

extract $2 $HWPACKDIR/ "HW Pack"
if [ ${hwpack_update_only} -eq 0 ]; then 
    extract $3 $ROOTFSDIR/ "RootFS"
fi

title "Copy U-Boot/SPL to SD Card"
copyUbootSpl $1 $HWPACKDIR/bootloader/sunxi-spl.bin
copyUboot $1 $HWPACKDIR/bootloader/u-boot.bin
mountPartitions $1
copyData
cleanup

echo "Done."
