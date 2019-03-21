#
# S60bashrc.mk
#
# add GXP path to /root/.bashrc
#

all :
	cat _bashrc >> $(custom_live_squashfs_master_root)/root/.bashrc 
