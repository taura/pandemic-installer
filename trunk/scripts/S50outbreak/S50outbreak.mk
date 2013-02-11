#
# S50outbreak.mk
#
# pre-download essential packages needed to run outbreak
#

outbreak_packages := realpath

all :
	chroot $(custom_live_squashfs_root) apt-get --force-yes -y --download-only --force-yes -y install $(outbreak_packages)

