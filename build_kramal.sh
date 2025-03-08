#!/usr/bin/env bash

set -e

KERNEL_DIR="$(pwd)"
CHAT_ID="-1002295046200"
TOKEN="7911765578:AAFN90U-GMGmzf5TINpbZKG8C0SuiKmRi_I"
DEVICE="Miatoll"
KERVER=$(make kernelversion)
VERSION=v1
DEFCONFIG="vendor/xiaomi/miatoll_defconfig"
IMAGE=${KERNEL_DIR}/out/arch/arm64/boot/Image
DTBO=${KERNEL_DIR}/out/arch/arm64/boot/dtbo.img
DTB=${KERNEL_DIR}/out/arch/arm64/boot/dts/qcom/cust-atoll-ab.dtb
ZIPNAME="kramal"
TANGGAL=$(date +"%F%S")
FINAL_ZIP="${ZIPNAME}-${VERSION}-${KERVER}-${DEVICE}-${TANGGAL}.zip"
COMPILER="llvm"
VERBOSE=0
USE_CCACHE=1  # Set to 1 to enable ccache, 0 to disable

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
    cd clang || exit 1
    wget -q https://github.com/ZyCromerZ/Clang/releases/download/21.0.0git-20250228-release/Clang-21.0.0git-20250228.tar.gz
    tar -xf Clang*
    cd "$KERNEL_DIR" || exit 1
    PATH="${KERNEL_DIR}/clang/bin:$PATH"
elif [ "$COMPILER" = "aosp" ]; then
    mkdir clang
    cd clang || exit
    wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r547379.tar.gz
    tar -xf clang*
    cd "$KERNEL_DIR" || exit 1
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git --depth=1 gcc
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git --depth=1 gcc32
    PATH="${KERNEL_DIR}/clang/bin:${KERNEL_DIR}/gcc/bin:${KERNEL_DIR}/gcc32/bin:${PATH}"
fi

# Get AnyKernel3 and KSU
git clone https://github.com/reaPeR1010/AnyKernel3 --depth=1
curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -

# Export Vars
KBUILD_BUILD_HOST="ArchLinux"
KBUILD_BUILD_USER="RoHaNRaJ"
KBUILD_COMPILER_STRING=$("${KERNEL_DIR}"/clang/bin/clang --version | head -n 1 | perl -pe 's/http.*?//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
PROCS=$(nproc --all)
export KBUILD_COMPILER_STRING KBUILD_BUILD_USER KBUILD_BUILD_HOST PROCS

function compile() {
    START=$(date +"%s")
    MAKE_OPT=()
    
    # If ccache is enabled, use it for compilation
    if [[ $USE_CCACHE -eq 1 ]]; then
        # Set ccache directory - works both in CI and local builds
        if [[ -n "${GITHUB_WORKSPACE}" ]]; then
            export CCACHE_DIR="${GITHUB_WORKSPACE}/.ccache"
        else
            export CCACHE_DIR="${KERNEL_DIR}/.ccache"
        fi
        
        export CCACHE_BASEDIR="$KERNEL_DIR"
        export CCACHE_COMPRESS=1
        export CCACHE_COMPRESSLEVEL=5
        export CCACHE_MAXSIZE=5G
        CCACHE_EXEC=$(which ccache)
        
        # Show ccache stats at the beginning
        echo "======= CCACHE STATS BEFORE BUILD ======="
        $CCACHE_EXEC -s
        
        MAKE_OPT+=(CC="${CCACHE_EXEC} clang" CXX="${CCACHE_EXEC} clang++" HOSTCC="${CCACHE_EXEC} clang" HOSTCXX="${CCACHE_EXEC} clang++")
    else
        MAKE_OPT+=(CC=clang CXX=clang HOSTCC=clang HOSTCXX=clang++)
    fi
    
    # Add compiler-specific flags
    if [ "$COMPILER" = "llvm" ]; then
        MAKE_OPT+=(CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi-)
    elif [ "$COMPILER" = "aosp" ]; then
        MAKE_OPT+=(CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_ARM32=arm-linux-androideabi-)
    fi
    MAKE_OPT+=(LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip READELF=llvm-readelf OBJSIZE=llvm-size)
    
    make O=out ARCH=arm64 $DEFCONFIG
    make -kj"$PROCS" O=out ARCH=arm64 LLVM_IAS=1 V=$VERBOSE "${MAKE_OPT[@]}" 2>&1 | tee error.log
    
    END=$(date +"%s")
    DIFF=$((END - START))
    
    # Show ccache stats after build if enabled
    if [[ $USE_CCACHE -eq 1 ]]; then
        echo "======= CCACHE STATS AFTER BUILD ======="
        $CCACHE_EXEC -s
    fi
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
