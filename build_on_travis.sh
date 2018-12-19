#/bin/bash
LIBARCHIVE_V=3.3.3
LIBARCHIVE_TARGZ=libarchive-${LIBARCHIVE_V}.tar.gz
LIBARCHIVE=https://www.libarchive.org/downloads/${LIBARCHIVE_TARGZ}
SCRIPT_ROOT_DIR=${PWD}

cd ${SCRIPT_ROOT_DIR}
######
# build libarchive (bsdtar)
curl -s ${LIBARCHIVE} | tar xvzf
cd ${LIBARCHIVE_TARGZ}
build/autogen.sh
./configure
make -j2
make install
export PATH=${PATH}:${SCRIPT_ROOT_DIR}/${LIBARCHIVE_TARGZ}

cd ${SCRIPT_ROOT_DIR}
#######
# build the image
make
