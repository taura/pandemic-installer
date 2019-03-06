#
# S50outbreak.mk
#
# pre-download essential packages needed to run outbreak
#

# 16.04 or earlier
#outbreak_packages := realpath
# 18.04 or earlier
outbreak_packages := coreutils

all :
#	chroot $(custom_live_squashfs_root) apt-get --force-yes -y --download-only install $(outbreak_packages)
	chroot $(custom_live_squashfs_root) apt-get -y --download-only install $(outbreak_packages)
	cp outbreak $(custom_live_squashfs_root)/root/

