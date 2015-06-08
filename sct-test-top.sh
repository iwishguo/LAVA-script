- job:
    name: linaro-edk2
    project-type: freestyle
    defaults: global
    logrotate:
        daysToKeep: 30
        numToKeep: 30
    properties:
        - authorization:
            anonymous:
                - job-read
                - job-extended-read
                - job-workspace
            leif.lindholm@linaro.org:
                - job-read
                - job-extended-read
                - job-build
                - job-cancel
    parameters:
        - string:
            name: BUNDLE_STREAM_NAME
            default: '/private/team/linaro/leg-edk2/'
        - string:
            name: DEVICE_TYPE
            default: 'rtsm_fvp_base-aemv8a'
        - string:
            name: LAVA_SERVER
            default: 'validation.linaro.org/RPC2/'
        - string:
            name: INITRD_URL
            default: 'http://releases.linaro.org/14.12/openembedded/images/minimal-initramfs-armv8/linaro-image-minimal-initramfs-genericarmv8-20141212-729.rootfs.cpio.gz'
    disabled: false
    node: build
    display-name: 'Linaro EDK II - UEFI Continuous Integration'
    scm:
        - git:
            url: http://git.linaro.org/git/uefi/linaro-edk2.git
            refspec: +refs/heads/release:refs/remotes/origin/release
            name: origin
            branches:
                - refs/heads/release
            basedir: linaro-edk2
            skip-tag: true
            shallow-clone: true
            clean: true
            wipe-workspace: false
    triggers:
        - pollscm: 'H/5 * * * *'
    wrappers:
        - timestamps
        - copy-to-slave:
            includes:
                - gcc-linaro-arm-linux-gnueabihf-4.8-2014.04_linux.tar.xz
                - gcc-linaro-aarch64-linux-gnu-4.8-2014.04_linux.tar.xz
        - build-name:
            name: '#${BUILD_NUMBER}-${GIT_REVISION,length=8}'
    builders:
        - linaro-publish-token
        - shell: |
            #!/bin/bash

            set -ex

            trap cleanup_exit INT TERM EXIT

            cleanup_exit()
            {
              cd ${WORKSPACE}
              rm -rf arm-tc
              rm -rf arm64-tc
              rm -rf uefi-ci uefi-tools
              rm -rf ${JOB_NAME}-build
              rm -rf out
            }

            # Install custom toolchain
            mkdir arm-tc arm64-tc
            tar --strip-components=1 -C ${WORKSPACE}/arm-tc -xf gcc-linaro-arm-linux-gnueabihf-4.8-*_linux.tar.xz
            tar --strip-components=1 -C ${WORKSPACE}/arm64-tc -xf gcc-linaro-aarch64-linux-gnu-4.8-*_linux.tar.xz
            export PATH="${WORKSPACE}/arm-tc/bin:${WORKSPACE}/arm64-tc/bin:$PATH"

            git clone git://git.linaro.org/uefi/uefi-tools.git
            git clone git://git.linaro.org/ci/uefi.git uefi-ci
            bash -x uefi-ci/uefi.sh

            builddir=${WORKSPACE}/${JOB_NAME}-build
            outdir=${WORKSPACE}/out
            mkdir -p ${outdir}
            mv ${builddir}/* ${outdir}/
            find ${outdir}/ -name '*QEMU_EFI.fd' -exec bash -c 'in=${1}; out=${in%fd}img; cat $in /dev/zero | dd iflag=fullblock bs=1M count=64 of=$out; gzip -9 $out' _ {} \;

            ${HOME}/bin/linaro-cp out components/kernel/${JOB_NAME}/${BUILD_NUMBER}

            IMAGE_BUILD_NUMBER=`wget -q --no-check-certificate -O - https://ci.linaro.org/jenkins/job/linux-leg/lastSuccessfulBuild/buildNumber`
            cat << EOF > lava_job_definition_parameters
            IMAGE_URL=http://snapshots.linaro.org/kernel-hwpack/linux-leg-vexpress64/${IMAGE_BUILD_NUMBER}/vexpress64-leg-sd.img.gz
            STARTUP_NSH=http://snapshots.linaro.org/kernel-hwpack/linux-leg-vexpress64/${IMAGE_BUILD_NUMBER}/startup.nsh
            EOF
        - inject:
            properties-file: lava_job_definition_parameters
        - shell: |
            BL1_URL=https://snapshots.linaro.org/components/kernel/${JOB_NAME}/${BUILD_NUMBER}/release/fvp_minimal/bl1.bin
            FIP_URL=https://snapshots.linaro.org/components/kernel/${JOB_NAME}/${BUILD_NUMBER}/release/fvp_minimal/fip.bin

            rm -rf configs
            git clone --depth 1 http://git.linaro.org/ci/job/configs.git

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
                < configs/linaro-edk2/lava-job-definitions/${DEVICE_TYPE}/template-grub-install.json \
                > custom_lava_job_definition_grub_install.json

            cat << EOF > post_build_lava_parameters_grub_install
            DEVICE_TYPE=${DEVICE_TYPE}
            BUNDLE_STREAM_NAME=${BUNDLE_STREAM_NAME}
            CUSTOM_JSON_URL=${JOB_URL}ws/custom_lava_job_definition_grub_install.json
            LAVA_SERVER=${LAVA_SERVER}
            EOF
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters_grub_install
              block: true
        - shell: |
            BL1_URL=https://snapshots.linaro.org/components/kernel/${JOB_NAME}/${BUILD_NUMBER}/release/fvp_minimal/bl1.bin
            FIP_URL=https://snapshots.linaro.org/components/kernel/${JOB_NAME}/${BUILD_NUMBER}/release/fvp_minimal/fip.bin

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
                < configs/linaro-edk2/lava-job-definitions/${DEVICE_TYPE}/template-startup-boot.json \
                > custom_lava_job_definition_startup_boot.json

            cat << EOF > post_build_lava_parameters_startup_boot
            DEVICE_TYPE=${DEVICE_TYPE}
            BUNDLE_STREAM_NAME=${BUNDLE_STREAM_NAME}
            CUSTOM_JSON_URL=${JOB_URL}ws/custom_lava_job_definition_startup_boot.json
            LAVA_SERVER=${LAVA_SERVER}
            EOF
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters_startup_boot
              block: true
        - shell: |
            BL1_URL=https://snapshots.linaro.org/components/kernel/${JOB_NAME}/${BUILD_NUMBER}/release/fvp_minimal/bl1.bin
            FIP_URL=https://snapshots.linaro.org/components/kernel/${JOB_NAME}/${BUILD_NUMBER}/release/fvp_minimal/fip.bin

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
                < configs/linaro-edk2/lava-job-definitions/${DEVICE_TYPE}/template-menu-boot.json \
                > custom_lava_job_definition_menu_boot.json

            cat << EOF > post_build_lava_parameters_menu_boot
            DEVICE_TYPE=${DEVICE_TYPE}
            BUNDLE_STREAM_NAME=${BUNDLE_STREAM_NAME}
            CUSTOM_JSON_URL=${JOB_URL}ws/custom_lava_job_definition_menu_boot.json
            LAVA_SERVER=${LAVA_SERVER}
            EOF
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters_menu_boot
              block: true
        - shell: |
            BL1_URL=https://snapshots.linaro.org/components/kernel/${JOB_NAME}/${BUILD_NUMBER}/release/fvp_minimal/bl1.bin
            FIP_URL=https://snapshots.linaro.org/components/kernel/${JOB_NAME}/${BUILD_NUMBER}/release/fvp_minimal/fip.bin

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
                < configs/linaro-edk2/lava-job-definitions/${DEVICE_TYPE}/template-menu-boot-with-initrd.json \
                > custom_lava_job_definition_menu_boot_with_initrd.json

            cat << EOF > post_build_lava_parameters_menu_boot_with_initrd
            DEVICE_TYPE=${DEVICE_TYPE}
            BUNDLE_STREAM_NAME=${BUNDLE_STREAM_NAME}
            CUSTOM_JSON_URL=${JOB_URL}ws/custom_lava_job_definition_menu_boot_with_initrd.json
            LAVA_SERVER=${LAVA_SERVER}
            EOF
        - trigger-builds:
            - project: 'post-build-lava'
              property-file: post_build_lava_parameters_menu_boot_with_initrd
              block: true
    publishers:
        - email:
            recipients: 'leif.lindholm@linaro.org fathi.boudra@linaro.org'
