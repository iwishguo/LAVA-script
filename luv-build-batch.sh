#!/bin/bash

set -x

HOME=/home/luv

ORI_PWD=`pwd`

cd $HOME
pwd

git clone http://git.linaro.org/people/naresh.bhat/luvOS/luv-yocto.git
cd luv-yocto
git branch v2-upstream origin/v2-upstream
git checkout v2-upstream
source ./oe-init-build-env
git clone http://github.com/iwishguo/LAVA-script.git
chmod a+x LAVA-script/*.pl
LAVA-script/modify_local_conf.pl conf/local.conf > conf/local.conf.new
mv conf/local.conf.new conf/local.conf
LAVA-script/modify_bb_conf.pl conf/bblayers.conf > conf/bblayers.conf.new
mv conf/bblayers.conf.new conf/bblayers.conf
bitbake luv-live-image 

cd $ORI_PWD

