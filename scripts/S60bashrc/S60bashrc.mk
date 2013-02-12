#
# S60bashrc.mk
#
# add GXP path to /root/.bashrc
#

all :
	echo >> $(custom_live_squashfs_root)/root/.bashrc 
	echo "export PATH=\$$PATH:/root/pi/tools/gxp3" >> $(custom_live_squashfs_root)/root/.bashrc

