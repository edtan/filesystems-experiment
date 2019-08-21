#!/bin/bash

# verify the kernel supports btrfs
cat /proc/filesystems | grep btrfs

# create a btrfs filesystem on the EBS volume.
# This needs to be done because btrfs is a filesystem dealing with actual
# block devices
sudo mkfs.btrfs -f /dev/xvdb

# mount the volume at /scratch
sudo mkdir /scratch
sudo mount -t btrfs /dev/xvdb /scratch
sudo chown -R $USER:$USER /scratch

# create a subvolume
btrfs subvolume create /scratch/subvolume1

# make test file with certain size
# (^C after a few seconds, results in 352MB file)
yes > /scratch/subvolume1/yes.txt     

# you can pass the --reflink option to cp now make a CoW copy of the file
cp --reflink /scratch/subvolume1/yes.txt /scratch/subvolume1/yes-copy.txt

# notice the difference between the file layer view (ls) and
# the block layer view (btrfs tools)
ls -l --human-readable /scratch/subvolume1/
#total 703M
#-rw-rw-r-- 1 ubuntu ubuntu 352M Aug 20 18:29 yes-copy.txt
#-rw-rw-r-- 1 ubuntu ubuntu 352M Aug 20 18:29 yes.txt

sudo btrfs filesystem show /dev/xvdb
#Label: none  uuid: 69e7407a-7bf2-4179-ac0e-ce342f091f54
#	Total devices 1 FS bytes used 351.74MiB
#	devid    1 size 8.00GiB used 1.08GiB path /dev/xvdb

# check the disk space usage.  "Set shared" is the all the space shared by
# all children of the argument to du (in this case, /scratch).  Notice 
# that the "set shared" is only the size of the original yes.txt
btrfs filesystem du /scratch
#     Total   Exclusive  Set shared  Filename
# 351.74MiB       0.00B           -  /scratch/subvolume1/yes.txt
# 351.74MiB       0.00B           -  /scratch/subvolume1/yes-copy.txt
# 703.48MiB       0.00B           -  /scratch/subvolume1
# 703.48MiB       0.00B   351.74MiB  /scratch

# check filesystem stats, may need to wait a while before running this
# command to have up to date stats
btrfs filesystem df /scratch  
#Data, single: total=840.00MiB, used=351.99MiB
#System, single: total=4.00MiB, used=16.00KiB
#Metadata, single: total=264.00MiB, used=512.00KiB
#GlobalReserve, single: total=16.00MiB, used=0.00B

# Notice that we get slightly differently stats from the df and du
# commands
df --human /scratch/
#Filesystem      Size  Used Avail Use% Mounted on
#/dev/xvdb       8.0G  369M  7.4G   5% /scratch

du --human --summarize /scratch/
#704M	/scratch/

# create (CoW) snapshot of subvolume1
btrfs subvolume snapshot /scratch/subvolume1/ /scratch/subvolume2

ls /scratch/subvolume2
#yes-copy.txt  yes.txt

# (^C after a second, results in 158MB file)
yes no > /scratch/subvolume2/no.txt

# Check the disk space usage again.  The "set shared" is still the same,
# because we've taken a snapshot of the original subvolume; thus, the
# snapshot points to the data in the original subvolume.  Additionally,
# we've created a new file no.txt in the snapshot (subvolume2) - you 
# can see that it has a non-zero "exclusive" size, meaning that its 
# data is not shared with any other files.
btrfs filesystem du /scratch
#     Total   Exclusive  Set shared  Filename
# 351.74MiB       0.00B           -  /scratch/subvolume1/yes.txt
# 351.74MiB       0.00B           -  /scratch/subvolume1/yes-copy.txt
# 703.48MiB       0.00B           -  /scratch/subvolume1
# 351.74MiB       0.00B           -  /scratch/subvolume2/yes.txt
# 351.74MiB       0.00B           -  /scratch/subvolume2/yes-copy.txt
# 157.06MiB   157.06MiB           -  /scratch/subvolume2/no.txt
# 860.54MiB   157.06MiB           -  /scratch/subvolume2
#   1.53GiB   157.06MiB   351.74MiB  /scratch

# create (CoW) snapshot of snapshot (subvolume2)
btrfs subvolume snapshot /scratch/subvolume2/ /scratch/subvolume3

ls /scratch/subvolume3
#no.txt  yes-copy.txt  yes.txt

btrfs filesystem du /scratch
#     Total   Exclusive  Set shared  Filename
# 351.74MiB       0.00B           -  /scratch/subvolume1/yes.txt
# 351.74MiB       0.00B           -  /scratch/subvolume1/yes-copy.txt
# 703.48MiB       0.00B           -  /scratch/subvolume1
# 351.74MiB       0.00B           -  /scratch/subvolume2/yes.txt
# 351.74MiB       0.00B           -  /scratch/subvolume2/yes-copy.txt
# 157.06MiB       0.00B           -  /scratch/subvolume2/no.txt
# 860.54MiB       0.00B           -  /scratch/subvolume2
# 351.74MiB       0.00B           -  /scratch/subvolume3/yes.txt
# 351.74MiB       0.00B           -  /scratch/subvolume3/yes-copy.txt
# 157.06MiB       0.00B           -  /scratch/subvolume3/no.txt
# 860.54MiB       0.00B           -  /scratch/subvolume3
#   2.37GiB       0.00B   508.80MiB  /scratch

btrfs filesystem df /scratch
#Data, single: total=840.00MiB, used=509.06MiB
#System, single: total=4.00MiB, used=16.00KiB
#Metadata, single: total=264.00MiB, used=704.00KiB
#GlobalReserve, single: total=16.00MiB, used=0.00B

df --human /scratch/
#Filesystem      Size  Used Avail Use% Mounted on
#/dev/xvdb       8.0G  526M  7.3G   7% /scratch

du --human --summarize /scratch/
#2.4G	/scratch/
