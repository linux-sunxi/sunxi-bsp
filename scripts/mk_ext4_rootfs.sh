

cleanup() {
	sudo umount $target
	sudo sudo rm -rf $target
}

die() {
	echo "$*" >&2
	cleanup
	exit 1
}

set -e

make_rootfs()
{
	echo "Make rootfs"
	local rootfs=$(readlink -f "$1")
	local output=$(readlink -f "$2")
	local fsizeinbytes=$(gzip -lq "$rootfs" | awk -F" " '{print $2}')
	local fsizeMB=$(expr $fsizeinbytes / 1024 / 1024 + 200)
	local target=$PWD"/target_tmp"
	local d= x=
	local rootfs_copied=

	echo "Make linux.ext4 (size="$fsizeMB")"
	mkdir -p $target
	rm -f linux.ext4
	dd if=/dev/zero of=linux.ext4 bs=1M count="$fsizeMB"
	mkfs.ext4 linux.ext4
	sudo mount linux.ext4 $target -o loop=/dev/loop0

	cd $target
	echo "Unpacking $rootfs"
	sudo tar xzpf $rootfs

	for x in '' \
		'binary/boot/filesystem.dir' 'binary'; do

		d="$target${x:+/$x}"

		if [ -d "$d/sbin" ]; then
			rootfs_copied=1
			sudo mv "$d"/* $target ||
				die "Failed to copy rootfs data"
			break
		fi
	done

	[ -n "$rootfs_copied" ] || die "Unsupported rootfs"

	cd - > /dev/null

	mv linux.ext4 $output
}

[ $# -eq 2 ] || die "Usage: $0 [rootfs.tar.gz] [output]"

make_rootfs "$1" "$2"
cleanup

