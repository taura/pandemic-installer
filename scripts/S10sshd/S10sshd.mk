#
# S10sshd.mk
#
# install OpenSSH server on the patient
# generate key on master
# copy master pubkey to the patient
#

all :
	chroot $(custom_live_squashfs_patient_root) apt-get -y --force-yes install openssh-server
	chroot $(custom_live_squashfs_root) ssh-keygen -N "" -f /root/.ssh/id_rsa
	chroot $(custom_live_squashfs_patient_root) ssh-keygen -N "" -f /root/.ssh/id_rsa
	cp $(custom_live_squashfs_root)/root/.ssh/id_rsa.pub $(custom_live_squashfs_patient_root)/root/.ssh/authorized_keys
