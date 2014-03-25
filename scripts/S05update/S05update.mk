#
# S05update.mk
#
# make sure we perform apt-get before anything
#

all :
	chroot $(custom_live_squashfs_patient_root) apt-get update
	chroot $(custom_live_squashfs_root) apt-get update
