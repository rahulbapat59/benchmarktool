#!/usr/bin/env bash

pushd ~/
sudo apt-get -y install libev-dev libgnutls28-dev
git clone https://github.com/shaygalon/htt2.git
sleep 10
pushd htt2
make
sleep 10
popd
popd
