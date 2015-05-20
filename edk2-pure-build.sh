#!/bin/bash
# Script used by CI to build Tiano edk2 upstream
# Requirements: uuid-dev package

set -ex

trap show_info EXIT

show_info ()
{
  set +x
  echo
  echo "Tiano edk2 revision $scm_commit"
  echo "Last build: $platform $build_type"
  echo
}

fetch_gcc ()
{
  pushd $DOWNLOAD_DIR
  file=$(echo -n $gcc_url | perl -F/ -ane 'print $F[@F-1]')
  if [ ! -f $file ]; then
    wget $gcc_url
  fi
  tar -C $TC_DIR -xf $file
  gcc_path=$(ls -d $TC_DIR/gcc*)
  export PATH=$gcc_path/bin:$PATH
  popd
}

clean_gcc ()
{
  rm -rf $gcc_path
}

clean_build ()
{
  rm -rf Build/*
}

if [ -z "${WORKSPACE}" ]; then
  # Local build
  export WORKSPACE=`pwd`
  export BUILD_NUMBER=0
  export JOB_NAME=${JOB_NAME:-tiano-edk2}
fi

# We do not build all arm targets to save time
#arm_platforms="a9 rtsm_a9x4 rtsm_a15x1 rtsm_a15mpcore tc2 qemu qemu-intelbds"
arm_platforms="tc2"
arm_gcc_urls="
http://releases.linaro.org/14.04/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.8-2014.04_linux.tar.xz
http://releases.linaro.org/14.11/components/toolchain/binaries/arm-linux-gnueabihf/gcc-linaro-4.9-2014.11-x86_64_arm-linux-gnueabihf.tar.xz
http://releases.linaro.org/13.04/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.7-2013.04-20130415_linux.tar.xz
http://releases.linaro.org/12.09/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-2012.09-20120921_linux.tar.bz2
"
aarch64_platforms="juno juno-intelbds fvp_full fvp fvp_minimal fvp_no_eth rtsm_aarch64 foundation_legacy qemu64 qemu64-intelbds"
aarch64_gcc_urls="
http://releases.linaro.org/14.04/components/toolchain/binaries/gcc-linaro-aarch64-linux-gnu-4.8-2014.04_linux.tar.xz
http://releases.linaro.org/14.11/components/toolchain/binaries/aarch64-linux-gnu/gcc-linaro-4.9-2014.11-x86_64_aarch64-linux-gnu.tar.xz
"

repo=edk2
pkg_repository=http://github.com/tianocore/edk2.git
branch=master

GCC_AARCH64_PREFIX=aarch64-linux-gnu-
GCC_ARM_PREFIX=arm-linux-gnueabihf-

#
# Check out linaro-edk2 sources
#
if [ ! -d ${repo} ]; then
	echo "Cloning ${repo}-${branch}"
	git clone --depth 1 ${pkg_repository} -b ${branch}
else
	echo "${repo} already exists; cleaning..."
	pushd ${repo}
#git clean -dfx
#git fetch origin
#	git branch -D ${branch} || true
#	git checkout --track origin/${branch}
	popd
fi

scm_commit=`cd ${repo} && git log -n1 --pretty=format:%h`
if [ -z "${scm_commit}" ]; then
	echo "invalid git revision: ${scm_commit}" >&2
	exit 1
fi

unset ARCH
export EDK2_DIR=${WORKSPACE}/${repo}
export TC_DIR=${WORKSPACE}/${JOB_NAME}-tc
export DOWNLOAD_DIR=${WORKSPACE}

if [ ! -d ${TC_DIR} ]; then
  mkdir -p ${TC_DIR}
fi

if [ ! -d ${DOWNLOAD_DIR} ]; then
  mkdir -p ${DOWNLOAD_DIR}
fi

# Get the UEFI tools
UEFI_TOOLS_DIR=${WORKSPACE}/uefi-tools
if [ ! -d ${UEFI_TOOLS_DIR} ]; then
	git clone git://git.linaro.org/uefi/uefi-tools.git
else
	echo #git --git-dir=${UEFI_TOOLS_DIR}/.git pull
fi

#
# Fix WORKSPACE environment variable conflict with Jenkins
# (Store Jenkins value before first edk2/SCT build step.)
#
JENKINS_WORKSPACE=${WORKSPACE}
unset WORKSPACE

for gcc_url in $aarch64_gcc_urls; do
  ORIGIN_PATH=$PATH
  fetch_gcc
  cd ${EDK2_DIR}
# build each platform once to make it terminate immediately when
# error occurs
  for platform in $aarch64_platforms; do
    build_type=RELEASE
    ${UEFI_TOOLS_DIR}/uefi-build.sh -b $build_type $platform
    build_type=DEBUG
    ${UEFI_TOOLS_DIR}/uefi-build.sh -b $build_type $platform
# To conserve disk space
    clean_build
  done
  PATH=$ORIGIN_PATH
  clean_gcc
done

for gcc_url in $arm_gcc_urls; do
  ORIGIN_PATH=$PATH
  fetch_gcc
  cd ${EDK2_DIR}
# build each platform once to make it terminate immediately when
# error occurs
  for platform in $arm_platforms; do
    build_type=RELEASE
    ${UEFI_TOOLS_DIR}/uefi-build.sh -b $build_type $platform
    build_type=DEBUG
    ${UEFI_TOOLS_DIR}/uefi-build.sh -b $build_type $platform
    clean_build
  done
  PATH=$ORIGIN_PATH
  clean_gcc
done

#
# Fix WORKSPACE environment variable conflict with Jenkins
# (Restore Jenkins value after last edk2/SCT build step.)
#
unset WORKSPACE
export WORKSPACE=${JENKINS_WORKSPACE}

# We want to return 0 if something built so that the files get copied to snapshots.linaro.org
exit 0
