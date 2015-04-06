OrangePi-bsp
=========

Getting Started
---------------

1. Choose a board doing:
   For Orange Pi:
   `./configure orangepi`,
   For Orange Pi mini:
   `./configure orangepimini`.

2. Run 'make' to build hwpack or 'make help' to list available targets


Overview
--------

This repository provides various scripts to help hacking devices with Allwinner SOC.

  ./scripts/
    a1x-initramfs.sh          - Create initramfs inside target device
    mk_ext4_rootfs.sh         - Ext4 rootfs from tar.gz
    mk_hwpack.sh              - Helper script for Makefile
    mk_livesuit_img.sh        - Android or Linux livesuit image
    sunxi-media-create.sh     - Flash SD card from hwpack
    mk_android.sh             - Helper script for Makefile
