#!/bin/bash

set -ex

#export BUNDLE_STREAM_NAME='/private/team/linaro/leg-edk2/'
export BUNDLE_STREAM_NAME='/anonymous/heyi-guo/'

export DEVICE_TYPE='rtsm_fvp_base-aemv8a'
export LAVA_SERVER='validation.linaro.org/RPC2/'
export INITRD_URL='http://releases.linaro.org/14.12/openembedded/images/minimal-initramfs-armv8/linaro-image-minimal-initramfs-genericarmv8-20141212-729.rootfs.cpio.gz'
export IMAGE_BUILD_NUMBER=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/linux-leg/lastSuccessfulBuild/buildNumber`
export BUILD_NUMBER=34
export JOB_NAME=linaro-edk2
export BUILD_URL=$JOB_NAME

cat << EOF > lava_job_definition_parameters
IMAGE_URL=http://snapshots.linaro.org/kernel-hwpack/linux-leg-vexpress64/${IMAGE_BUILD_NUMBER}/vexpress64-leg-sd.img.gz
STARTUP_NSH=http://snapshots.linaro.org/kernel-hwpack/linux-leg-vexpress64/${IMAGE_BUILD_NUMBER}/startup.nsh
EOF
BL1_URL=https://snapshots.linaro.org/components/kernel/${JOB_NAME}/${BUILD_NUMBER}/release/fvp_minimal/bl1.bin
FIP_URL=https://snapshots.linaro.org/components/kernel/${JOB_NAME}/${BUILD_NUMBER}/release/fvp_minimal/fip.bin

#rm -rf configs
#git clone --depth 1 http://git.linaro.org/ci/job/configs.git

sed -e "s|\${BUILD_NUMBER}|${BUILD_NUMBER}|" \
    -e "s|\${BUILD_URL}|${BUILD_URL}|" \
    -e "s|\${BUNDLE_STREAM_NAME}|${BUNDLE_STREAM_NAME}|" \
    -e "s|\${BL1_URL}|${BL1_URL}|" \
    -e "s|\${FIP_URL}|${FIP_URL}|" \
    -e "s|\${INITRD_URL}|${INITRD_URL}|" \
    -e "s|\${STARTUP_NSH}|${STARTUP_NSH}|" \
    -e "s|\${DEVICE_TYPE}|${DEVICE_TYPE}|" \
    -e "s|\${GIT_BRANCH}|${GIT_BRANCH}|" \
    -e "s|\${GIT_COMMIT}|${GIT_COMMIT}|" \
    -e "s|\${GIT_URL}|${GIT_URL}|" \
    -e "s|\${IMAGE_URL}|${IMAGE_URL}|" \
    -e "s|\${LAVA_SERVER}|${LAVA_SERVER}|" \
    < configs/linaro-edk2/lava-job-definitions/${DEVICE_TYPE}/template-sct-install-and-run.json \
    > custom_lava_job_definition_sct-install-and-run.json

lava-tool submit-job https://heyi-guo@validation.linaro.org/RPC2/ custom_lava_job_definition_sct-install-and-run.json


