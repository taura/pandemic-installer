#
# S15svn.mk
#

all :
	chroot $(custom_live_squashfs_root) apt-get install subversion
