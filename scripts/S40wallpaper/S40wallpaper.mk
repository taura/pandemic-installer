#
# S40wallpaper.mk
#
# Change wallpapers
#

all :
	cp wallpaper-master.png $(custom_live_squashfs_master_root)/usr/share/backgrounds/warty-final-ubuntu.png
	cp wallpaper-client.png $(custom_live_squashfs_client_root)/usr/share/backgrounds/warty-final-ubuntu.png

