#!/bin/bash
# This script will download images from MSCOCO along with information about them to make them usable in the context of neurotalk. 

# Usage: ./build-dataset.sh <path/to/target/folder> 
# Global variables
TARGET_PATH="$1"
MYNAME="$(readlink -f "$0")"
MYDIR="$(dirname "${MYNAME}")"

function ensure_cmd_or_install_package_apt() {
  local CMD=$1
  shift
  local PKG=$*
  hash $CMD 2>/dev/null || { 
    log warn $CMD not available. Attempting to install $PKG
    (sudo apt-get update -yqq && sudo apt-get install -yqq ${PKG}) || die "Could not find $PKG"
  }
}

function is_sudoer() {
    CAN_RUN_SUDO=$(sudo -n uptime 2>&1|grep "load"|wc -l)
    if [ ${CAN_RUN_SUDO} -gt 0 ]
    then
        echo 1
    else
        echo 0
    fi
}

# Check if we are sudoer or not
if [ $(is_sudoer) -eq 0 ]; then
    die "You must be root or sudo to run this script"
fi

# Eventually installing dependencies
ensure_cmd_or_install_package_apt jq jq
ensure_cmd_or_install_package_apt wget wget

echo "Creating Target folder"
[ -d "${TARGET_PATH}" ] && echo "Target path already started, moving forward" || mkdir -p "${TARGET_PATH}"

# Creating MD5 sum file for large file download validation
cat > /tmp/md5sum.txt << EOF
5750999c8c964077e3c81581170be65b  ${TARGET_PATH}/captions_train-val2014.zip
68baf1a0733e26f5878a1450feeebc20  ${TARGET_PATH}/train2014.zip
a3d79f5ed8d289b7a7554ce06a5782b3  ${TARGET_PATH}/val2014.zip
441315b0ff6932dbfde97731be7ca852  ${TARGET_PATH}/VGG_ILSVRC_16_layers.caffemodel
c70550f8203a4eaae53d7c39ef34c92d  ${TARGET_PATH}/VGG_ILSVRC_16_layers_deploy.prototxt
94ebdf3dad7ca2a5b2a10c9d0ba63d14  ${TARGET_PATH}/cocotalk.h5.tar.gz 
68fc477e92cba25a3faefed57d4b5944  ${TARGET_PATH}coco_raw.json.tar.gz
530ba6ea54141eedf8e68f2a5224a6be  ${TARGET_PATH}cocotalk.json.tar.gz
EOF

cd ${TARGET_PATH}
DONE=-1

until [ ${DONE} -eq 0 ]; do

	echo "Downloading files"
	wget -qc http://msvocds.blob.core.windows.net/annotations-1-0-3/captions_train-val2014.zip & 
	wget -qc http://msvocds.blob.core.windows.net/coco2014/train2014.zip &
	wget -qc http://msvocds.blob.core.windows.net/coco2014/val2014.zip &
	wget -qc http://www.robots.ox.ac.uk/~vgg/software/very_deep/caffe/VGG_ILSVRC_16_layers.caffemodel &
	wget -qc https://gist.githubusercontent.com/ksimonyan/211839e770f7b538e2d8/raw/0067c9b32f60362c74f4c445a080beed06b07eb3/VGG_ILSVRC_16_layers_deploy.prototxt &
	# The below are files we are building in the build-dataset.sh 
	wget -qc https://s3-us-west-2.amazonaws.com/samnco-static-files/datasets/coco_raw.json.tar.gz & 
	wget -qc https://s3-us-west-2.amazonaws.com/samnco-static-files/datasets/cocotalk.h5.tar.gz & 
	wget -qc https://s3-us-west-2.amazonaws.com/samnco-static-files/datasets/cocotalk.json.tar.gz & 

	echo "Now waiting for all threads to end"
	wait
	echo "Done waiting for threads. Computing MD5SUM"

	DONE=$(md5sum -c /tmp/md5sum.txt | grep 'FAILED' | wc -l)
done

echo "All files downloaded"

# Build the raw JSON file
for file in train2014.zip val2014.zip captions_train-val2014.zip
do 
	echo "Uncompressing ${file}"
	unzip "${file}" && mv "${file}" /tmp/
done

for file in coco_raw.json.tar.gz
do 
	echo "Uncompressing ${file}"
	tar xfz "${file}" && mv "${file}" /tmp/
done


# replace image with problem
echo "Replacing MS COCO failed image by a fresh and working one"
wget -qc https://msvocds.blob.core.windows.net/images/262993_z.jpg && \
mv 262993_z.jpg "${TARGET_PATH}/train2014/COCO_train2014_000000167126.jpg"

echo "OK, all files downloaded and prep'd! You can safely move to training"
