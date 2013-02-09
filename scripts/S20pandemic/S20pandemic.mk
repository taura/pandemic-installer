#
# S20pandemic.mk
#
# pre-download pandemic installer directory in the master's root
# so that we can just run become_pandemic_master
#

pandemic_packages := isc-dhcp-server tftpd-hpa nfs-kernel-server syslinux 
all :
# download tools we need in the master, but not install
	chroot $(custom_live_squashfs_root) apt-get --force-yes -y --download-only install $(pandemic_packages)
	chroot $(custom_live_squashfs_root) apt-get --force-yes -y install subversion
	chroot $(custom_live_squashfs_root) rm -rf /root/pi
	chroot $(custom_live_squashfs_root) svn checkout http://pandemic-installer.googlecode.com/svn/trunk /root/pi
