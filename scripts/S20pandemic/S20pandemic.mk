#
# S20pandemic.mk
#
# pre-download pandemic installer directory in the master's root
# so that we can just run become_pandemic_master
#

pandemic_packages := isc-dhcp-server tftpd-hpa nfs-kernel-server syslinux pxelinux coreutils make
all :
# download tools we need in the master, but not install
	chroot $(custom_live_squashfs_root) apt-get --force-yes -y --download-only install $(pandemic_packages)
	chroot $(custom_live_squashfs_root) apt-get --force-yes -y install git
	chroot $(custom_live_squashfs_root) rm -rf /root/pi
	chroot $(custom_live_squashfs_root) git clone https://github.com/taura/pandemic-installer.git /root/pi
#	chroot $(custom_live_squashfs_root) svn checkout http://pandemic-installer.googlecode.com/svn/branches/14.04 /root/pi
# 	chroot $(custom_live_squashfs_root) svn checkout http://pandemic-installer.googlecode.com/svn/trunk /root/pi
# 	Copy scripts
# 	mkdir $(custom_live_squashfs_root)/root/pi
# 	cp -r ../../README $(custom_live_squashfs_root)/root/pi/
# 	cp -r ../../become_pandemic_master $(custom_live_squashfs_root)/root/pi/
# 	cp -r ../../master_scripts $(custom_live_squashfs_root)/root/pi/
# 	cp -r ../../scripts $(custom_live_squashfs_root)/root/pi/
# 	cp -r ../../misc $(custom_live_squashfs_root)/root/pi/
# 	cp -r ../../tools $(custom_live_squashfs_root)/root/pi/

