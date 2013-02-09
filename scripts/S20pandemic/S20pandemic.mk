#
# S20pandemic.mk
#
# pre-download pandemic installer directory in the master's root
# so that we can just run become_pandemic_master
#

all :
	chroot $(custom_live_squashfs_root) rm -rf /root/pi
	chroot $(custom_live_squashfs_root) svn checkout http://pandemic-installer.googlecode.com/svn/trunk /root/pi
	chroot $(custom_live_squashfs_root) apt-get --download-only --force-yes -y install isc-dhcp-server tftpd-hpa nfs-kernel-server syslinux
