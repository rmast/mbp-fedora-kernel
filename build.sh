#!/bin/bash

set -eu -o pipefail

## Update fedora docker image tag, because kernel build is using `uname -r` when defining package version variable
RPMBUILD_PATH=/root/rpmbuild
MBP_VERSION=mbp
FEDORA_KERNEL_VERSION=5.18.13-200.fc36      # https://bodhi.fedoraproject.org/updates/?search=&packages=kernel&releases=F36
REPO_PWD=$(pwd)

### Debug commands
echo "FEDORA_KERNEL_VERSION=$FEDORA_KERNEL_VERSION"

pwd
echo "CPU threads: $(nproc --all)"
grep 'model name' /proc/cpuinfo | uniq

### Dependencies
dnf install -y fedpkg fedora-packager rpmdevtools ncurses-devel pesign git libkcapi libkcapi-devel libkcapi-static libkcapi-tools zip curl dwarves libbpf rpm-sign

## Set home build directory
rpmdev-setuptree

## Install the kernel source and finish installing dependencies
cd ${RPMBUILD_PATH}/SOURCES
koji download-build --arch=src kernel-${FEDORA_KERNEL_VERSION}
rpm -Uvh kernel-${FEDORA_KERNEL_VERSION}.src.rpm

cd ${RPMBUILD_PATH}/SPECS
dnf -y builddep kernel.spec

echo >&2 "===]> Info: Applying kconfig changes... ";
echo "CONFIG_PMIC_OPREGION=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_BYTCRC_PMIC_OPREGION=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_I2C_DESIGNWARE_CORE=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_I2C_DESIGNWARE_PLATFORM=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_I2C_DESIGNWARE_BAYTRAIL=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_I2C_DESIGNWARE_PCI=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_GPIO_CRYSTAL_COVE=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_INTEL_SOC_PMIC=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_MEDIA_SUPPORT=m" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_MEDIA_SUPPORT_FILTER=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_VIDEO_ADV_DEBUG=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_STAGING=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_STAGING_MEDIA=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_INTEL_ATOMISP=y" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_VIDEO_ATOMISP=m" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_VIDEO_ATOMISP_ISP2401=n" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_VIDEO_ATOMISP_MSRLIST_HELPER=m" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_VIDEO_ATOMISP_MT9M114=m" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_INTEL_ATOMISP2_LED" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_V4L2_CCI" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_V4L2_CCI_I2C" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_INTEL_ATOMISP2_PDX86" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_PWM_LPSS_PCI" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_IPU_BRIDGE" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_INTEL_VSC" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_VIDEO_ATOMISP_GC0310=n" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_VIDEO_ATOMISP_OV2680=n" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_VIDEO_ATOMISP_OV5693=n" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"
echo "CONFIG_VIDEO_ATOMISP_LM3554=n" >> "${RPMBUILD_PATH}/SOURCES/kernel-local"

### Change buildid to mbp
echo >&2 "===]> Info: Setting kernel name...";
sed -i "s/# define buildid.*/%define buildid .${MBP_VERSION}/" "${RPMBUILD_PATH}"/SPECS/kernel.spec

### Build non-debug kernel rpms
echo >&2 "===]> Info: Bulding kernel ...";
cd "${RPMBUILD_PATH}"/SPECS
rpmbuild -bb --with baseonly --without debug --without debuginfo --target=x86_64 kernel.spec
rpmbuild_exitcode=$?

### Build non-debug mbp-fedora-t2-config rpms
cp -rfv "${REPO_PWD}"/yum-repo/mbp-fedora-t2-config/rpm.spec ./
cp -rfv "${REPO_PWD}"/yum-repo/mbp-fedora-t2-config/suspend/rmmod_tb.sh ${RPMBUILD_PATH}/SOURCES
find .
pwd
rpmbuild -bb --without debug --without debuginfo --target=x86_64 rpm.spec

### Copy artifacts to shared volume
echo >&2 "===]> Info: Copying rpms and calculating SHA256 ...";
cd "${REPO_PWD}"
mkdir -p ./output_zip
cp -rfv ${RPMBUILD_PATH}/RPMS/x86_64/*.rpm ./output_zip/
sha256sum ${RPMBUILD_PATH}/RPMS/x86_64/*.rpm > ./output_zip/sha256

### Add patches to artifacts
zip -r patches.zip patches/
cp -rfv patches.zip ./output_zip/
echo
du -sh ./output_zip
echo
du -sh ./output_zip/*.rpm

exit $rpmbuild_exitcode
