#
# S15efi.mk
#
all :
	mkdir -p $(custom_live_squashfs_extract)/EFI $(custom_live_squashfs_master_root)/boot/efi/
	cp -r    $(custom_live_squashfs_extract)/EFI $(custom_live_squashfs_master_root)/boot/efi/
