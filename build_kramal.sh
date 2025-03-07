#!/usr/bin/env bash

set -e
KERNEL_DIR="$(pwd)"
CHAT_ID="-1002295046200"
TOKEN="7911765578:AAFN90U-GMGmzf5TINpbZKG8C0SuiKmRi_I"
COMPILER="aosp"

# Deps
if [ $COMPILER = "clang" ];
then
mkdir clang
cd clang || exit
wget -q https://github.com/ZyCromerZ/Clang/releases/download/21.0.0git-20250214-release/Clang-21.0.0git-20250214.tar.gz
tar -xf Clang*
cd .. || exit
PATH="${KERNEL_DIR}/clang/bin:$PATH"
elif [ $COMPILER = "gcc" ];
then
mkdir gcc && cd gcc
wget -q https://github.com/mvaisakh/gcc-build/releases/download/26012025/eva-gcc-arm64-26012025.xz
wget -q https://github.com/mvaisakh/gcc-build/releases/download/26012025/eva-gcc-arm-26012025.xz
ls *.xz | xargs -n1 tar -xf
cd .. || exit
PATH="${KERNEL_DIR}/gcc/gcc-arm64/bin/:${KERNEL_DIR}/gcc/gcc-arm/bin/:/usr/bin:${PATH}"
elif [ $COMPILER = "aosp" ];
then
mkdir aosp-clang
cd aosp-clang || exit
wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r547379.tar.gz
tar -xf clang*
cd .. || exit
git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git --depth=1 gcc
git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git  --depth=1 gcc32
PATH="${KERNEL_DIR}/aosp-clang/bin:${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:${PATH}"
fi

git clone https://github.com/reaPeR1010/AnyKernel3 --depth=1
curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -
# VARS
DEVICE="Miatoll"
KERVER=$(make kernelversion)
VERSION=v1
IMAGE=${KERNEL_DIR}/out/arch/arm64/boot/Image
DTBO=${KERNEL_DIR}/out/arch/arm64/boot/dtbo.img
DTB=${KERNEL_DIR}/out/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb
ZIPNAME="kramal"
TANGGAL=$(date +"%F%S")
FINAL_ZIP="${ZIPNAME}-${VERSION}-${KERVER}-${DEVICE}-${TANGGAL}.zip"
KBUILD_BUILD_HOST="ArchLinux"
KBUILD_BUILD_USER="RoHaNRaJ"
if [ $COMPILER = "clang" ];
then
KBUILD_COMPILER_STRING=$("${KERNEL_DIR}"/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
elif [ $COMPILER = "gcc" ];
then
KBUILD_COMPILER_STRING=$("${KERNEL_DIR}"/gcc/gcc-arm64/bin/aarch64-elf-gcc --version | head -n 1)
elif [ $COMPILER = "aosp" ];
then
KBUILD_COMPILER_STRING=$("${KERNEL_DIR}"/aosp-clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
fi
PROCS="$(nproc --all)"
export KBUILD_COMPILER_STRING KBUILD_BUILD_USER KBUILD_BUILD_HOST PROCS

TG_PUSH()
{
	curl --progress-bar -F document=@"$1" https://api.telegram.org/bot$TOKEN/sendDocument \
	-F chat_id="$CHAT_ID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown"
}

function compile() {
# Compile
make O=out ARCH=arm64 vendor/xiaomi/miatoll_defconfig
if [ $COMPILER = "clang" ];
then
make -kj"${PROCS}" O=out ARCH=arm64 CC=clang HOSTCC=clang HOSTCXX=clang++ LLVM_IAS=1 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip READELF=llvm-readelf OBJSIZE=llvm-size 2>&1 | tee build.log
elif [ $COMPILER = "gcc" ];
then
make -kj"${PROCS}" O=out ARCH=arm64 CROSS_COMPILE_ARM32=arm-eabi- CROSS_COMPILE=aarch64-elf- 2>&1 | tee build.log
elif [ $COMPILER = "aosp" ];
then
make -kj"${PROCS}" O=out ARCH=arm64 CC=clang HOSTCC=clang HOSTCXX=clang++ LLVM_IAS=1 CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_ARM32=arm-linux-androideabi- LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip READELF=llvm-readelf OBJSIZE=llvm-size 2>&1 | tee build.log
fi
}

function zipping() {
if ! [ -a "$IMAGE" ];
then
echo "Build Throws Errors"
TG_PUSH "build.log"
exit 1
else
mv "$IMAGE" AnyKernel3
mv "$DTB" AnyKernel3/dtb
mv "$DTBO" AnyKernel3

# Zipping and Push Kernel
cd AnyKernel3
zip -r9 "${FINAL_ZIP}" * -x  .git README.md
fi
}

function upload() {
curl bashupload.com -T "${FINAL_ZIP}"
TG_PUSH "${FINAL_ZIP}"
}

compile
zipping
upload
