#/bin/bash

wget https://www.libarchive.org/downloads/libarchive-3.3.1.tar.gz
tar xzf libarchive-3.3.1.tar.gz
cd libarchive-3.3.1
./build/autogen.sh
./configure
make
sudo make install

cd ..
make
