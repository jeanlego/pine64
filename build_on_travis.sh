#/bin/bash
set -e

LIBARCHIVE_V=3.3.3
LIBARCHIVE_FILE=libarchive-${LIBARCHIVE_V}
LIBARCHIVE_TARGZ=${LIBARCHIVE_FILE}.tar.gz
LIBARCHIVE=https://www.libarchive.org/downloads/${LIBARCHIVE_TARGZ}
SCRIPT_ROOT_DIR=${PWD}

cd ${SCRIPT_ROOT_DIR}
######
# build libarchive (bsdtar)
curl -s ${LIBARCHIVE} | tar xz
cd ${LIBARCHIVE_FILE}
build/autogen.sh
./configure
make -j2
export PATH=${PATH}:${SCRIPT_ROOT_DIR}/${LIBARCHIVE_FILE}

cd ${SCRIPT_ROOT_DIR}
#######
# build the image

./make_image.sh archlinux-sopine-headless.img u-boot-sunxi-with-spl-sopine.bin
