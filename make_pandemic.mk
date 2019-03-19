# ------------------------------------
# make_pandemic.mk
#  creates a custom live CD from the default CD
# ------------------------------------
# Need:
#   squashfs-tools
#   syslinux
#
# Usage:
#  1. prepare the default Ubuntu Live CD
#    (by default, ubuntu-14.04.3-desktop-amd64.iso;
#     can be specified below)
#  2. run this script on your laptop by:
#
#        sudo make -f make_pandemic.mk usb
#
#  with luck, you will have a file system image at /tmp/root/custom_live
#  
#  3. plug a FAT-formatted USB stick into the PC and burn the file 
#  system image into it by:
#
#        sudo make -f make_pandemic.mk burn_usb
#
# How it works:
#  it basically follows information at
#    https://help.ubuntu.com/community/LiveCDCustomization
#
# Note: 
#  I tried Ubuntu Customization Kit:
#   http://sourceforge.net/projects/uck/
# but it didn't quite work as expected.  
# The process failed in my Ubuntu 12.04.  
#
# What kind of cutomizations are actually performed?
# - currently, the customizatoion performed is just add
#   OpenSSH server. see README why we need it
# - eventually, we will put more stuff, so that the
#   pandemic server brings up and is immediately ready
#   for installing clients
#
# ------------------------------------

ifneq ($(wildcard config.mk),)
include config.mk
endif

# ---------- variables you might want to specify ----------
# (1) original image file name; absolute path or relative to current dir
orig_iso ?= $(shell ls ubuntu-*.iso | tail -1)
ifeq ($(orig_iso),)
$(error "orig_iso not defined. put ubuntu iso in the directory or specify one in config.mk")
endif

# (2) if you want to create a custom ISO image file, give its filename.
# this MUST BE an absolute path
cust_iso ?= $(realpath .)/custom-$(shell ls ubuntu-*.iso | tail -1)
ifeq ($(cust_iso),)
$(error "cust_iso not defined. put ubuntu iso in the directory or specify one in config.mk")
endif

# (3) image name of your ISO image (if you want to create one), 
# which in practice does not matter
image_name ?= Customized Ubuntu

# (4) work dir in which we extract the whole file system for the master. 
# should use fast and large enough drive to 
# store the decompressed image (2GB?)
work_dir ?= /tmp/$(shell whoami)/custom_live

# (5) try to find usb stick's partition (e.g., /dev/sdb1), device (/dev/sdb),
# and its mount point

usb_part ?= $(shell mount | awk '/fat/ && !/boot/ { print $$1 }')
# usb_dev  ?= $(shell mount | awk '$$1 == usb_part { print substr($$1, 1, length($$1)-1) }' usb_part=$(usb_part))
usb_dev  ?= $(shell awk 'BEGIN { x="$(usb_part)"; sub("[0-9]", "", x); print x; }')
usb_mnt  ?= $(shell mount | awk '$$1 == usb_part { print $$3 }' usb_part=$(usb_part))

#usb_part ?= $(shell mount | awk '/fat/ { print $$1 }')
#usb_dev  ?= $(shell mount | awk '/fat/ { print substr($$1, 1, length($$1)-1) }')
#usb_mnt  ?= $(shell mount | awk '/fat/ { print $$3 }')


# (6) mbr record to dump into usb stick ; 
# taken from syslinux package, but you may have your own tarball
mbr_bin  ?= $(shell ls /usr/lib/syslinux/mbr/mbr.bin /usr/lib/syslinux/mbr.bin 2> /dev/null | head -1)

# (7) menu.c32 file written to usb stick
# taken from syslinux package, but you may have your own tarball
syslinux_menu ?= $(shell ls /usr/lib/syslinux/modules/efi64/menu.c32 /usr/lib/syslinux/menu.c32 2> /dev/null | head -1)

# (8) if you want to test usb drive with virtualbox, you may convert
# usb stck to a vmdk file; name its file name (totally optional)
usb_vmdk ?= usb.vmdk

# 
#export pandemic_master_if:=eth0
#export pandemic_master_ipaddr:=10.0.3.15
#export pandemic_master_netmask:=255.255.255.0
#export pandemic_master_broadcast:=10.0.3.255

# ---------- derived pathnames ----------

# directory to which we mount iso
mnt := $(work_dir)/mnt
# directory to which we extract contents of iso
extract := $(work_dir)/ext
# directory in which we edit the file system image in iso
# (/casper/filesystem.squash)
export custom_live_squashfs_extract := $(extract)
export custom_live_squashfs_root := $(work_dir)/edit
export custom_live_squashfs_patient_root := $(work_dir)/patient_edit

$(info orig_iso=$(orig_iso))
$(info cust_iso=$(cust_iso))
$(info work_dir=$(work_dir))
$(info mnt=$(mnt))
$(info extract=$(extract))
$(info custom_live_squashfs_root=$(custom_live_squashfs_root))
$(info ******** check if the following seems correct ********)
$(info usb_part=$(usb_part))
$(info usb_dev=$(usb_dev))
$(info usb_mnt=$(usb_mnt))
$(info ******************************************************)

# ---------- targets ----------

# all : $(cust_iso)
all : help

help :
	@echo "0. install squashfs-tools and syslinux (using apt-get)"
	@echo "1. prepare the default Ubuntu Live CD"
	@echo "  (by default, ubuntu-14.04.3-desktop-amd64.iso;"
	@echo "   can be specified below)"
	@echo "2. run this script on your laptop by:"
	@echo ""
	@echo "        sudo make -f make_pandemic.mk usb"
	@echo ""
	@echo "  with luck, you will have a file system image at /tmp/root/custom_live"
	@echo ""
	@echo "3. plug a FAT-formatted USB stick into the PC and burn the file "
	@echo "system image into it by:"
	@echo ""
	@echo "        sudo make -f make_pandemic.mk burn_usb"
	@echo ""
	@echo "4. now you should be able to boot the master PC with the USB stick!"

usb : $(extract)/casper/filesystem.squashfs
burn_usb : $(usb_mnt)/syslinux.cfg
iso : $(cust_iso)

check_tools :
	@echo "checking whether you have syslinux ..."
	ls $(mbr_bin)
	ls $(syslinux_menu)
	@echo "OK, you have syslinux"
	@echo "checking whether you have squashfs-tools ..."
	which unsquashfs
	@echo "checking whether you have syslinux-utils ..."
	which isohybrid
	@echo "OK, you have squashfs-tools"

# STEP 1:
# mount ISO image file to a working directory $(mnt)
# in case it is already mounted, try umount first.
# on success, we must have $(mnt)/casper, among others
$(mnt)/casper : $(orig_iso) check_tools
	@echo "============== STEP 1 : mount Ubuntu ISO =============="
	[ `whoami` = root ]
	mkdir -p $(mnt)
	umount -lf $(mnt) 2> /dev/null; mount -o loop,ro $(orig_iso) $(mnt)
	ls -d $@

# STEP 2:
# now we have ISO image accessible under $(mnt)
# extract its contents, except for filesystem.squashfs (the main
# file system tree image) into another working directory $(extract)
$(extract)/extract_ok : $(mnt)/casper
	@echo "============== STEP 2 : extract ISO files =============="
	[ `whoami` = root ]
	mkdir -p $(extract)
	rsync --exclude /casper/filesystem.squashfs -a $(mnt)/ $(extract)
	touch $@

# STEP 3:
# extract the main file system tree into another working 
# directory $(custom_live_squashfs_root), by unsquashing /casper/filesystem.squashfs
# in the ISO image
$(custom_live_squashfs_root)/root_ok : $(mnt)/casper $(extract)/extract_ok
	@echo "============== STEP 3.1 : unsquash into a directory tree for master =============="
	[ `whoami` = root ]
	rm -rf $(custom_live_squashfs_root)
	unsquashfs -d $(custom_live_squashfs_root) $(mnt)/casper/filesystem.squashfs
	touch $@

$(custom_live_squashfs_patient_root)/patient_root_ok : $(mnt)/casper $(extract)/extract_ok
	@echo "============== STEP 3.2 : unsquash into a directory tree for clients =============="
	[ `whoami` = root ]
	rm -rf $(custom_live_squashfs_patient_root)
	unsquashfs -d $(custom_live_squashfs_patient_root) $(mnt)/casper/filesystem.squashfs
	touch $@

# STEP 4:
# here is the actual customization we perform.
#  - install OpenSSH server
#  - install key pair so that the pandemic master which exports
#    the same CD image to its clients can ssh to them
$(custom_live_squashfs_root)/customize_ok : $(custom_live_squashfs_root)/root_ok $(custom_live_squashfs_patient_root)/patient_root_ok
# you must sudo 
	@echo "============== STEP 4 : edit master and client directory trees =============="
	[ `whoami` = root ]
# prepare: mount important file system
	@echo "============== STEP 4.1 : mount special file systems =============="
	umount -lf $(custom_live_squashfs_root)/dev             2> /dev/null || :
	mount --bind /dev/ $(custom_live_squashfs_root)/dev
	chroot $(custom_live_squashfs_root) umount -lf /proc    2> /dev/null || :
	chroot $(custom_live_squashfs_root) mount -t proc none /proc
	chroot $(custom_live_squashfs_root) umount -lf /sys     2> /dev/null || :
	chroot $(custom_live_squashfs_root) mount -t sysfs none /sys
	chroot $(custom_live_squashfs_root) umount -lf /dev/pts 2> /dev/null || :
	chroot $(custom_live_squashfs_root) mount -t devpts none /dev/pts
	cp /etc/resolv.conf $(custom_live_squashfs_root)/etc/resolv.conf
# ditto, but for patient
	umount -lf $(custom_live_squashfs_patient_root)/dev             2> /dev/null || :
	mount --bind /dev/ $(custom_live_squashfs_patient_root)/dev
	chroot $(custom_live_squashfs_patient_root) umount -lf /proc    2> /dev/null || :
	chroot $(custom_live_squashfs_patient_root) mount -t proc none /proc
	chroot $(custom_live_squashfs_patient_root) umount -lf /sys     2> /dev/null || :
	chroot $(custom_live_squashfs_patient_root) mount -t sysfs none /sys
	chroot $(custom_live_squashfs_patient_root) umount -lf /dev/pts 2> /dev/null || :
	chroot $(custom_live_squashfs_patient_root) mount -t devpts none /dev/pts
	cp /etc/resolv.conf $(custom_live_squashfs_patient_root)/etc/resolv.conf
	@echo "============== STEP 4.2 : customize master/clients file systems =============="
# now real work; we may want to extend this part in future
	for d in $(shell ls -1d scripts/S*/); do $(MAKE) -C $$d -f `basename $$d`.mk || exit 1 ; done
# clean up 
# try unmounting until we succeed or failed 10 times
	@echo "============== STEP 4.3 : unmount special file systems =============="
	for d in dev sys proc dev/pts; do \
		for i in `seq 1 10`; do \
			if mountpoint $(custom_live_squashfs_root)/$${d} ; then \
				umount $(custom_live_squashfs_root)/$${d} ; \
			else \
				echo "umount /$${d} OK" ; break; \
			fi ; \
			sleep 1; \
		done | grep "OK" || echo "could not umount /$${d}, ignore an keep going" ; \
	done
# unmount patient root
	for d in dev sys proc dev/pts; do \
		for i in `seq 1 10`; do \
			if mountpoint $(custom_live_squashfs_patient_root)/$${d} ; then \
				umount $(custom_live_squashfs_patient_root)/$${d} ; \
			else \
				echo "umount /$${d} OK" ; break; \
			fi ; \
			sleep 1; \
		done | grep "OK" || echo "could not umount /$${d}, ignore an keep going" ; \
	done
	touch $@

# STEP 5:
# now we have a custom file system tree in $(custom_live_squashfs_root)
# package it into a squashfs file in $(extract)
# also create its manifest, which must exist in live CD
$(extract)/casper/filesystem.squashfs : $(custom_live_squashfs_root)/customize_ok  $(extract)/extract_ok
	@echo "============== STEP 5 : make squashed file system =============="
	[ `whoami` = root ]
# mksquash patient root into master root
	rm -rf $(custom_live_squashfs_root)/patient_root
	mkdir -p $(custom_live_squashfs_root)/patient_root/casper
	mksquashfs $(custom_live_squashfs_patient_root) $(custom_live_squashfs_root)/patient_root/casper/filesystem.squashfs
	chroot $(custom_live_squashfs_root) dpkg-query -W --showformat='$${Package} $${Version}\n' > $(extract)/casper/filesystem.manifest
	printf `du -sx --block-size=1 $(custom_live_squashfs_root) | cut -f1` > $(extract)/casper/filesystem.size
	rm -f $(extract)/casper/filesystem.squashfs
	mksquashfs $(custom_live_squashfs_root) $(extract)/casper/filesystem.squashfs

# STEP 6:
# now $(extract) contains everything we need to put in ISO
# image. now create iso image.
# - create md5sum
# - create .iso file, the final product
$(cust_iso) : $(extract)/casper/filesystem.squashfs
	[ `whoami` = root ]
	cd $(extract) && find -type f -print0 | xargs -0 md5sum | grep -v isolinux/boot.cat | tee md5sum.txt
	cd $(extract) && mkisofs -D -r -V "$(image_name)" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $(cust_iso) .
	isohybrid $(cust_iso)

$(usb_mnt)/syslinux.cfg : $(extract)/casper/filesystem.squashfs
	@echo checking device/parition/mount point of usb drives
	[ "$(usb_dev)" != "" ]
#	[ "$(usb_mnt)" != "" ]
#	[ "$(usb_part)" != "" ]
#	@echo "checking partition $(usb_part) is a fat partition"
#	mount | grep $(usb_part) | grep fat
#	mount | grep $(usb_dev) | grep fat
ifeq (0,0)
	@echo "============== burning image into USB =============="
ifneq ($(usb_mnt),)
	umount $(usb_mnt)
endif
# make gpt partition table
	(echo g; echo w) | fdisk $(usb_dev)
	sleep 2
# make a new EFI partition
	(echo n; echo ; echo ; echo +3M ; echo t ; echo ; echo 1 ; echo w) | fdisk $(usb_dev)
	sleep 2
# format with fat
	echo y | mkfs -t fat $(usb_dev)1
	sleep 2
# make a new Linux partition
	(echo n; echo ; echo ; echo ; echo w) | fdisk $(usb_dev) # +4612M 
	sleep 2
# format with ext4
	echo y | mkfs -t ext4 $(usb_dev)2
	sleep 2
# mount EFI
	mkdir -p EFI
	mount $(usb_dev)1 EFI
# copy EFI
	rsync -avz $(extract)/EFI EFI/
	umount EFI
	rmdir -p EFI
# mount root fs
	mkdir -p ROOT
	mount $(usb_dev)2 ROOT
# copy root fs
	rsync -avz $(extract)/ ROOT/
# unmount
	umount ROOT
	rmdir -p ROOT
else
	parted $(usb_dev) set 1 boot on
	syslinux -i $(usb_part)
	dd conv=notrunc bs=440 count=1 if=$(mbr_bin) of=$(usb_dev)
	rm -rf $(usb_mnt)/casper/  && cp -r $(extract)/casper/ $(usb_mnt)/
	rm -rf $(usb_mnt)/.disk    && cp -r $(extract)/.disk $(usb_mnt)/
	rm -f $(usb_mnt)/menu.c32  && cp $(syslinux_menu) $(usb_mnt)/menu.c32
	cp misc/syslinux.cfg $(usb_mnt)/syslinux.cfg
endif

# clean up working directory.
# we must make sure /proc, /sys, /dev/pts are unmounted
# before we erase the directory
clean :
	[ `whoami` = root ]
# unmount master root
	for d in dev sys proc dev/pts; do \
		for i in `seq 1 10`; do \
			if mountpoint $(custom_live_squashfs_root)/$${d} ; then \
				umount $(custom_live_squashfs_root)/$${d} ; \
			else \
				echo "umount $${d} OK" ; break; \
			fi ; \
			sleep 1; \
		done | grep "OK" || exit 1 ; \
	done
# unmount patient root
	for d in dev sys proc dev/pts; do \
		for i in `seq 1 10`; do \
			if mountpoint $(custom_live_squashfs_patient_root)/$${d} ; then \
				umount $(custom_live_squashfs_patient_root)/$${d} ; \
			else \
				echo "umount $${d} OK" ; break; \
			fi ; \
			sleep 1; \
		done | grep "OK" || exit 1 ; \
	done
	umount -lf $(mnt) ; : 
	rmdir $(mnt) ; : 
	rm -rf $(custom_live_squashfs_root) ; : 
	rm -rf $(custom_live_squashfs_patient_root) ; : 
	rm -rf $(extract) ; :
	rm -rf $(work_dir) ; :

# http://oshiete.goo.ne.jp/qa/7295624.html
make_virtualbox_bootable_usb : $(usb_vmdk)
$(usb_vmdk) : 
	VBoxManage internalcommands createrawvmdk -filename $(usb_vmdk) -rawdisk $(usb_dev)


# TODO:
# mess around root check, device check, vmdk creation
#

