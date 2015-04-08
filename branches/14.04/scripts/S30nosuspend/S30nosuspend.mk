#
# S30nosuspend.mk
#
# disable suspend on closing laptop
#

all :
	cp 10_disable-suspend.gschema.override $(custom_live_squashfs_root)/usr/share/glib-2.0/schemas/
	cp 10_disable-suspend.gschema.override $(custom_live_squashfs_patient_root)/usr/share/glib-2.0/schemas/
