#!/usr/bin/env bash

set -e

KERNEL_DIR="$(pwd)"
CHAT_ID="-1002295046200"
TOKEN="7911765578:AAFN90U-GMGmzf5TINpbZKG8C0SuiKmRi_I"
DEVICE="miatoll"
VERSION=v1
DEFCONFIG="vendor/xiaomi/miatoll_defconfig"
IMAGE=${KERNEL_DIR}/out/arch/arm64/boot/Image
DTBO=${KERNEL_DIR}/out/arch/arm64/boot/dtbo.img
DTB=${KERNEL_DIR}/out/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb
ZIPNAME="nexus"
TANGGAL=$(date +"%Y%m%d-%H%M")
FINAL_ZIP="${ZIPNAME}-${VERSION}-${DEVICE}-${TANGGAL}.zip"
COMPILER="" # llvm or default inbuilt
VERBOSE=0

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
    mkdir -p clang && wget -qO- https://github.com/ZyCromerZ/Clang/releases/download/21.0.0git-20250611-release/Clang-21.0.0git-20250611.tar.gz | tar -xz -C clang
    PATH="${KERNEL_DIR}/clang/bin:$PATH"
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
    make O=out ARCH=arm64 $DEFCONFIG LLVM=1
    make -kj"$PROCS" O=out ARCH=arm64 LLVM=1 V=$VERBOSE 2>&1 | tee error.log

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
        zip -r9 "${FINAL_ZIP}" * -x .git README.md
        cd "$KERNEL_DIR" || exit 1
    fi
}
function upload() {
    telegram_push "AnyKernel3/${FINAL_ZIP}" "Build took : $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)"
    exit 0
}
# Main execution flow
compile
zipping
upload
