#
# S70automaster.mk
#
# automatically start master services
#

all :
	cp automaster $(custom_live_squashfs_root)/etc/init.d/
	chroot $(custom_live_squashfs_root) update-rc.d automaster defaults

