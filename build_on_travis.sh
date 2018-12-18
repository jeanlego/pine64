#/bin/bash
LIBARCHIVE_V=3.3.3
LIBARCHIVE=https://www.libarchive.org/downloads/libarchive-${LIBARCHIVE_V}.tar.gz

SCRIPT_ROOT_DIR=${PWD}

cd ${SCRIPT_ROOT_DIR}
######
# build libarchive (bsdtar)
mkdir -p libarchive
curl -s ${LIBARCHIVE} | tar xvzf - -C libarchive/
cd libarchive
./build/autogen.sh
./configure
make -j2
make install
export PATH=${PATH}:${SCRIPT_ROOT_DIR}/libarchive

cd ${SCRIPT_ROOT_DIR}
#######
# build the image
make
