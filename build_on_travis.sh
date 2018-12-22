#!/bin/bash

ROOT_DIR=${PWD}

git clone git://git.qemu.org/qemu.git
cd qemu
git submodule update --init --recursive

./configure --prefix=$(cd ..; pwd)/qemu-user-static --static --disable-system --enable-linux-user
make -j$(( $(nproc --all) +1 ))
make install

cd ../qemu-user-static/bin
for i in *
do 
  cp $i $i-static
done

cd ${ROOT_DIR}
./build_image.sh
