#
# S05update.mk
#
# make sure we perform apt-get before anything
#

all :
	chroot $(custom_live_squashfs_client_root) apt-get update
	chroot $(custom_live_squashfs_master_root) apt-get update
