#
# S40wallpaper.mk
#
# Change wallpapers
#

all :
	cp wallpaper-master.png $(custom_live_squashfs_root)/usr/share/backgrounds/warty-final-ubuntu.png
	cp wallpaper-patient.png $(custom_live_squashfs_patient_root)/usr/share/backgrounds/warty-final-ubuntu.png

