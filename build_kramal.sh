#!/usr/bin/env bash

set -e

KERNEL_DIR="$(pwd)"
CHAT_ID="-1002295046200"
TOKEN="7911765578:AAFN90U-GMGmzf5TINpbZKG8C0SuiKmRi_I"
DEVICE="miatoll"
VERSION=v2
DEFCONFIG="vendor/xiaomi/miatoll_defconfig"
IMAGE=${KERNEL_DIR}/out/arch/arm64/boot/Image
DTBO=${KERNEL_DIR}/out/arch/arm64/boot/dtbo.img
DTB=${KERNEL_DIR}/out/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb
KERNELNAME="nexus"
TANGGAL=$(date +"%Y%m%d-%H%M")
ZIPNAME="${KERNELNAME}-${VERSION}-${DEVICE}-${TANGGAL}.zip"
if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
    ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi
COMPILER="" # llvm or default (aosp) inbuilt
VERBOSE=0

# Modify defconfig
del_config() {
    sed -i "/^$1=y$/d" "arch/arm64/configs/$DEFCONFIG"
}

add_config() {
    del_config "$1"
    echo "# $1 is not set" >> "arch/arm64/configs/$DEFCONFIG"
}

# Telegram messaging function
telegram_push() {
  curl --progress-bar -F document=@"$1" https://api.telegram.org/bot$TOKEN/sendDocument \
	-F chat_id="$CHAT_ID"  \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2"
}

# Set up the Compiler
if [ "$COMPILER" = "llvm" ]; then
mkdir -p clang
wget -qO- https://www.kernel.org/pub/tools/llvm/files/llvm-21.1.2-x86_64.tar.gz | tar --strip-components=1 -xz -C clang
PATH="${KERNEL_DIR}/clang/bin:$PATH"
elif [ "$COMPILER" = "gcc" ]; then
mkdir -p gcc-arm64 gcc-arm
wget -qO- https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/x86_64/15.2.0/x86_64-gcc-15.2.0-nolibc-aarch64-linux.tar.gz | tar --strip-components=2 -xz -C gcc-arm64
wget -qO- https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/x86_64/15.2.0/x86_64-gcc-15.2.0-nolibc-arm-linux-gnueabi.tar.gz | tar --strip-components=2 -xz -C gcc-arm
PATH="${KERNEL_DIR}/gcc-arm64/bin/:${KERNEL_DIR}/gcc-arm/bin/:/usr/bin:${PATH}"
fi

# Get AnyKernel3
git clone https://github.com/reaPeR1010/AnyKernel3 --depth=1

# Export Vars
KBUILD_BUILD_HOST="ArchLinux"
KBUILD_BUILD_USER="RoHaNRaJ"
PROCS=$(nproc --all)
export KBUILD_BUILD_USER KBUILD_BUILD_HOST PROCS

function compile() {
    START=$(date +"%s")
    if [ "$COMPILER" = "gcc" ]; then
    del_config CONFIG_TOOLS_SUPPORT_RELR
    make O=out ARCH=arm64 $DEFCONFIG
    make -kj"$PROCS" O=out CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- V=$VERBOSE 2>&1 | tee error.log
    else
    make O=out ARCH=arm64 $DEFCONFIG LLVM=1
    make -kj"$PROCS" O=out LLVM=1 V=$VERBOSE 2>&1 | tee error.log

    END=$(date +"%s")
    DIFF=$((END - START))

}
function zipping() {
    if [ ! -f "$IMAGE" ]; then
        telegram_push "error.log" "**Build Failed:** Kernel compilation threw errors"
        exit 1
    else
        mv "$IMAGE" AnyKernel3
        mv "$DTB" AnyKernel3/dtb
        mv "$DTBO" AnyKernel3
        cd AnyKernel3 || exit 1
        zip -r9 "${ZIPNAME}" * -x .git README.md
        cd "$KERNEL_DIR" || exit 1
    fi
}
function upload() {
    telegram_push "AnyKernel3/${ZIPNAME}" "Build took : $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)"
    exit 0
}
# Main execution flow
compile
zipping
upload
