#!/bin/bash
# ---------------------------------------------------------
# Script to automate linux custom iso creation.
# This script also creates a vm if asked to help debug / test
# functionalities. Needs kvm for vm creation.
# Author: Pierre Engelstein
# ---------------------------------------------------------


function help() {
	echo "usage: create_iso_ubuntu <input iso> <output iso>"
}

#===================================
# Extract iso file in $1 to a temporary directory (returned as echo)
#===================================
function extract_iso() {
	# create a temporary directory to mount the iso
	TMP=$(mktemp -d)
	sudo mount -o loop $1 $TMP
	TMP1=$(mktemp -d)
	sudo cp -pRf $TMP/. $TMP1/
	sudo chown -R $USER:$USER $TMP1/
	sudo umount $TMP
	rm -rf $TMP
	echo $TMP1
}

iso_name=$1
iso_output=$2
workingdir=$(pwd)
if [ -z $iso_name ]; then
	help
	exit
fi

if [ -z $iso_output ]; then
	help
	exit
fi

if [ -f $iso_output ]; then
        read -p "[WARNING] File $iso_output already exists. Do you wish to delete it ? [y/N]" choice
	case "$choice" in
            y|Y )
                rm $iso_output
                ;;
            * )
                echo "[ERROR] Cancelling iso creation, exiting."
                exit
                ;;
        esac


fi

echo "[INFO] Extracting iso $iso_name" 
extracted_folder=$(extract_iso $iso_name)
echo "[INFO] Extraction done to $extracted_folder"

cd $extracted_folder

#TMP_squashfs=$(mktemp -d)
#sudo mount -t squashfs -o loop ./casper/filesystem.squashfs $TMP_squashfs
#TMP_squashfs_copy=$(mktemp -d)
#echo "[INFO] Extracting filesystem.squashfs to $TMP_squashfs_copy ..."
#sudo rsync -a --info=progress2 $TMP_squashfs/. $workingdir/squashfs
#sudo umount $TMP_squashfs
#sudo rm -rf $TMP_squashfs
#echo "[INFO] Extraction done."

echo "[INFO] Copying filesystem.squashfs to $workingdir/filesystem.squashfs"
sudo rm -rf $workingdir/filesystem.squashfs
sudo rm -rf $workingdir/squashfs-root
sudo cp $extracted_folder/casper/filesystem.squashfs $workingdir/filesystem.squashfs
echo "[INFO] Copy done."

echo "[INFO] Unsquashing filesystem.squashfs to $workingdir/squashfs-root"
cd $workingdir
sudo unsquashfs filesystem.squashfs
echo "[INFO] Unsquashing done."

echo "[INFO] Entering chroot to $workingdir/squashfs-root"
echo "[DEBUG] Copy setup files to squashfs root"
sudo cp $workingdir/setup.sh $workingdir/squashfs-root/setup.sh
sudo cp $workingdir/.zshrc $workingdir/squashfs-root/etc/skel/.zshrc
echo "[DEBUG] Mount proc to /proc & sysfs to /sys"
sudo chroot $workingdir/squashfs-root /bin/bash -c "mount -t proc none /proc"
sudo chroot $workingdir/squashfs-root /bin/bash -c "mount -t sysfs none /sys"
#echo "[DEBUG] apt update"
#sudo chroot $workingdir/squashfs-root /bin/bash -c "apt update"
#echo "[DEBUG] apt upgrade"
#sudo chroot $workingdir/squashfs-root /bin/bash -c "apt upgrade -y"
echo "[DEBUG] Run setup script"
sudo chroot $workingdir/squashfs-root /bin/bash -c "chmod +x setup.sh && ./setup.sh"
echo "[DEBUG] apt clean"
sudo chroot $workingdir/squashfs-root /bin/bash -c "apt-get -qq clean"
echo "[DEBUG] unmount proc & sys"
sudo chroot $workingdir/squashfs-root /bin/bash -c "umount /proc"
sudo chroot $workingdir/squashfs-root /bin/bash -c "umount /sys"

echo "[INFO] Repacking squashfs file system"
sudo mksquashfs $workingdir/squashfs-root new_filesystem.squashfs -noappend
sudo rm $extracted_folder/casper/filesystem.squashfs
sudo cp $workingdir/new_filesystem.squashfs $extracted_folder/casper/filesystem.squashfs
echo "[INFO] Repacking done."

cd $extracted_folder

chmod +w isolinux/isolinux.bin
mkisofs -o $iso_output -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -r -T . 
cd $workingdir

rm -rf test_popos.qcow2
qemu-img create -f qcow2 test_popos.qcow2 120G
virt-install --name test_popos --ram 8192 --vcpus 4 --disk path=test_popos.qcow2 --os-type linux --os-variant ubuntu20.10 --network network=default --cdrom $iso_output --sound none --virt-type kvm

sudo rm -rf $extracted_folder
