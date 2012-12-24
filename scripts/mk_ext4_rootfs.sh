

die() {
	echo "$*" >&2
	exit 1
}

set -e

make_rootfs()
{
	echo "Make rootfs"
	local f=$(readlink -f "$1")
	local fsizeinbytes=$(gzip -lq "$f" | awk -F" " '{print $2}')
	local fsizeMB=$(expr $fsizeinbytes / 1024 / 1024 + 200)
	local target=$PWD"/target_tmp"

	echo "Make linux.ext4 (size="$fsizeMB")"
	mkdir -p $target
	rm -f linux.ext4
	dd if=/dev/zero of=linux.ext4 bs=1M count="$fsizeMB"
	mkfs.ext4 linux.ext4
	sudo mount linux.ext4 $target -o loop=/dev/loop0

	cd $target
	sudo tar xzf "$f"
	if [ -d ./etc ]; then
		echo "Standard rootfs"
		# do nothing
	elif [ -d ./binary/boot/filesystem.dir ]; then
		echo "Linaro rootfs"
		sudo mv ./binary/boot/filesystem.dir/* .
		sudo rm -rf ./binary
	else
		die "Unsupported rootfs"
	fi
	cd - > /dev/null

	sudo umount $target
	sudo sudo rm -rf $target

	mv linux.ext4 "$2"
}

[ $# -eq 2 ] || die "Usage: $0 [rootfs.tar.gz] [output]"

make_rootfs "$1" "$2"

