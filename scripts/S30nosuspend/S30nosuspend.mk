#
# S30nosuspend.mk
#
# disable suspend on closing laptop
#

all :
# old ubuntu
#	cp 10_disable-suspend.gschema.override $(custom_live_squashfs_master_root)/usr/share/glib-2.0/schemas/
#	cp 10_disable-suspend.gschema.override $(custom_live_squashfs_client_root)/usr/share/glib-2.0/schemas/
	echo 'HandleLidSwitch=ignore'       | tee --append $(custom_live_squashfs_master_root)/etc/systemd/logind.conf
	echo 'HandleLidSwitchDocked=ignore' | tee --append $(custom_live_squashfs_master_root)/etc/systemd/logind.conf
	echo 'HandleLidSwitch=ignore'       | tee --append $(custom_live_squashfs_client_root)/etc/systemd/logind.conf
	echo 'HandleLidSwitchDocked=ignore' | tee --append $(custom_live_squashfs_client_root)/etc/systemd/logind.conf
