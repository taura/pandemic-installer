#
# S70automaster.mk
#
# automatically start master services
#

all :
	cp automaster $(custom_live_squashfs_master_root)/etc/init.d/
	cp automaster.service $(custom_live_squashfs_master_root)/etc/systemd/system/
#	chroot $(custom_live_squashfs_master_root) update-rc.d automaster defaults
	chroot $(custom_live_squashfs_master_root) systemctl enable automaster

