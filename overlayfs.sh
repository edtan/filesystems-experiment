#!/bin/bash

# Create a working directory, and create the lower, upper, workdir, and
# overlay directories in it in preparation for an OverlayFS mount
mkdir -p overlay-test/{lower,upper,workdir,overlay}
mkdir -p overlay-test/lower/samedir
mkdir -p overlay-test/upper/samedir
cd overlay-test

# Create files in the lower and upper directories for each case, a file
# only in the lower directory, a file only in the upper directory, and a
# file in both the lower and upper directories.  Additionally, create the
# same set of files within a subdirectories of the lower and upper
# directories to show what happens when directories are "merged" together
# in OverlayFS
echo "This is only-in-lower.txt in the lower dir" | tee lower/only-in-lower.txt lower/samedir/only-in-lower.txt
echo "This is lower.txt in the lower dir" | tee lower/lower.txt lower/samedir/lower.txt
echo "This is upper.txt in the upper dir" | tee upper/upper.txt upper/samedir/upper.txt
echo "This is same.txt in the lower dir" | tee lower/same.txt lower/samedir/same.txt
echo "This is same.txt in the upper dir" | tee upper/same.txt upper/samedir/same.txt

# This is what the directories look like before mounting OverlayFS:
tree
#.
#├── lower
#│   ├── lower.txt
#│   ├── only-in-lower.txt
#│   ├── samedir
#│   │   ├── lower.txt
#│   │   ├── only-in-lower.txt
#│   │   └── same.txt
#│   └── same.txt
#├── overlay
#├── upper
#│   ├── samedir
#│   │   ├── same.txt
#│   │   └── upper.txt
#│   ├── same.txt
#│   └── upper.txt
#└── workdir

# Notice we didn't have to issue a "mkfs" command like we did for btrfs,
# because this isn't a "real" filesystem dealing with block devices - we're
# just using directories on the existing filesystem.
sudo mount -t overlay overlay -o lowerdir=lower,upperdir=upper,workdir=workdir overlay

# Notice that the overlay/ directory is now a combined view of the lower
# and upper directories!
tree
#.
#├── lower
#│   ├── lower.txt
#│   ├── only-in-lower.txt
#│   ├── samedir
#│   │   ├── lower.txt
#│   │   ├── only-in-lower.txt
#│   │   └── same.txt
#│   └── same.txt
#├── overlay
#│   ├── lower.txt
#│   ├── only-in-lower.txt
#│   ├── samedir
#│   │   ├── lower.txt
#│   │   ├── only-in-lower.txt
#│   │   ├── same.txt
#│   │   └── upper.txt
#│   ├── same.txt
#│   └── upper.txt
#├── upper
#│   ├── samedir
#│   │   ├── same.txt
#│   │   └── upper.txt
#│   ├── same.txt
#│   └── upper.txt
#└── workdir
#    └── work [error opening dir]

# Notice that the same.txt is the one visible in the OverlayFS mount
cat overlay/same.txt
#This is same.txt in the upper dir

# Now let's modify same.txt in the OverlayFS mount, and see what happens
# to the underlying files in the lower and upper directories
echo "Modifying the same.txt" > overlay/same.txt

# The same.txt in the upper directory was modified!
cat upper/same.txt 
#Modifying the same.txt

# But same.txt in the lower directory was left intact
cat lower/same.txt 
#This is same.txt in the lower dir

# Now let's try modifying the same.txt file in the upper directory and
# see what happens in the OverlayFS mount
echo "Modifying the same.txt in upper dir directly" > upper/same.txt

# Success!  We can see the changes that were made directly in the upper
# directory
cat overlay/same.txt
#Modifying the same.txt in upper dir directly

# Now, the next example shows how we can create another OverlayFS using
# an existing OverlayFS as a lower dir.  We create a new set of directories
# except for the lower directory, which we'll reuse from the previous
# example.
mkdir -p {upper2,workdir2,overlay2}

ls
#lower  overlay  overlay2  upper  upper2  workdir  workdir2

# For good measure, let's create a new file in the new upper2 directory
echo "This is upper2.txt in the upper2 dir" | tee upper2/upper2.txt

# Create the second OverlayFS mount, using the previous OverlayFS mount
sudo mount -t overlay overlay -o lowerdir=overlay,upperdir=upper2,workdir=workdir2 overlay2

# Notice how overlay2 like the previous OverlayFS mount (overlay/) combined
# with the new upper2/ directory
tree
#.
#├── lower
#│   ├── lower.txt
#│   ├── only-in-lower.txt
#│   ├── samedir
#│   │   ├── lower.txt
#│   │   ├── only-in-lower.txt
#│   │   └── same.txt
#│   └── same.txt
#├── overlay
#│   ├── lower.txt
#│   ├── only-in-lower.txt
#│   ├── samedir
#│   │   ├── lower.txt
#│   │   ├── only-in-lower.txt
#│   │   ├── same.txt
#│   │   └── upper.txt
#│   ├── same.txt
#│   └── upper.txt
#├── overlay2
#│   ├── lower.txt
#│   ├── only-in-lower.txt
#│   ├── samedir
#│   │   ├── lower.txt
#│   │   ├── only-in-lower.txt
#│   │   ├── same.txt
#│   │   └── upper.txt
#│   ├── same.txt
#│   ├── upper2.txt
#│   └── upper.txt
#├── upper
#│   ├── samedir
#│   │   ├── same.txt
#│   │   └── upper.txt
#│   ├── same.txt
#│   └── upper.txt
#├── upper2
#│   └── upper2.txt
#├── workdir
#│   └── work [error opening dir]
#└── workdir2
#    └── work [error opening dir]

# However, trying to "nest" an independent OverlayFS within an Overlay
# directory is not possible.
# Create a new, independent set of lower, upper, workdir, and overlay
# directories completely within the existing overlay/ mount
cd overlay
mkdir -p {innerlower,innerupper,innerworkdir,inneroverlay}

# Examine the contents within overlay/
tree
#.
#├── innerlower
#├── inneroverlay
#├── innerupper
#├── innerworkdir
#├── lower.txt
#├── only-in-lower.txt
#├── samedir
#│   ├── lower.txt
#│   ├── only-in-lower.txt
#│   ├── same.txt
#│   └── upper.txt
#├── same.txt
#└── upper.txt

# Let's see if this works...
sudo mount -t overlay overlay -o lowerdir=inneroverlay,upperdir=innerupper,workdir=innerworkdir inneroverlay

# nope!

#mount: wrong fs type, bad option, bad superblock on overlay,
#       missing codepage or helper program, or other error
#
#       In some cases useful info is found in syslog - try
#       dmesg | tail or so.

# Finally, let's just take a look at file sizes to constrast this with
# btrfs.  This also results in some confusing file sizes, where it
# looks like overlay is actually more than the sum of lower and upper
# in this example.
# (I don't know why overlay/ is more than lower and upper - possibly
# because the file sizes are so small and perhaps the metadata ends up
# being larger than the file sizes.)

# I've filtered out the output to show only the lines of interest
df --human    
#Filesystem      Size  Used Avail Use% Mounted on
#/dev/sda6       111G  104G  916M 100% /
#overlay         111G  104G  916M 100% /home/user/overlay-test/overlay
#overlay         111G  104G  916M 100% /home/user/overlay-test/overlay2

sudo du --human --summarize *
#32K	lower
#56K	overlay
#60K	overlay2
#40K	upper
#4.0K	upper2
#8.0K	workdir
#8.0K	workdir2

# Let's generate a large file in lower/ and see what the file sizes
# look like then
# (^C after a few seconds results in a 323MB file)
yes > lower/yes.txt

# The results suggest that overlay/ and overlay2/ are pointing to the
# yes.txt in lower/ instead of being copies.
# However, the regular user-space df and du don't really show what
# data is shared

# I've filtered out the output to show only the lines of interest
df --human
#Filesystem      Size  Used Avail Use% Mounted on
#/dev/sda6       111G  105G  594M 100% /
#overlay         111G  105G  594M 100% /home/user/overlay-test/overlay
#overlay         111G  105G  594M 100% /home/user/overlay-test/overlay2

sudo du --human --summarize *
#3323M	lower
#3375M	overlay
#3375M	overlay2
#340K	upper
#34.0K	upper2
#38.0K	workdir
#38.0K	workdir2

# clean up
sudo umount overlay2
sudo umount overlay
cd ..
rm -rf overlay-test
