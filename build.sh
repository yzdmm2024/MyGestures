#!/bin/bash
# ============================================================
# MyGestures 一键编译脚本
# 在 WSL / Ubuntu / Debian Linux 或 macOS 上运行:
#     cd 手势插件 && bash build.sh
#
# 首次运行会自动安装 Theos(含 iOS 工具链和 SDK), 需要联网。
# 之后每次运行直接编译, 产物是 packages/ 目录下的 .deb
# ============================================================
set -e
cd "$(dirname "$0")"

# ---------- 1. Linux 依赖 ----------
if [ "$(uname -s)" = "Linux" ]; then
    NEED=""
    for pkg in curl git perl rsync fakeroot xz-utils make; do
        command -v "$pkg" >/dev/null 2>&1 || NEED="$NEED $pkg"
    done
    if [ -n "$NEED" ]; then
        echo "[*] 安装缺失依赖:$NEED"
        sudo apt-get update -y || apt-get update -y
        sudo apt-get install -y $NEED || apt-get install -y $NEED
    fi
fi

# ---------- 2. Theos ----------
export THEOS="${THEOS:-$HOME/theos}"
if [ ! -d "$THEOS" ]; then
    echo "[*] 未检测到 Theos, 使用官方脚本安装到 $THEOS ..."
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
fi

# 确保 16.5 SDK 存在 (没有则从 theos/sdks 补齐)
if [ ! -d "$THEOS/sdks/iPhoneOS16.5.sdk" ]; then
    echo "[*] 补充下载 iPhoneOS16.5 SDK ..."
    TMP=$(mktemp -d)
    git clone --depth 1 --filter=blob:none --sparse https://github.com/theos/sdks.git "$TMP/sdks"
    cd "$TMP/sdks" && git sparse-checkout set iPhoneOS16.5.sdk && cd - >/dev/null
    mkdir -p "$THEOS/sdks"
    cp -R "$TMP/sdks/iPhoneOS16.5.sdk" "$THEOS/sdks/"
    rm -rf "$TMP"
fi

# ---------- 3. 编译 (rootless) ----------
export THEOS_PACKAGE_SCHEME=rootless
echo "[*] 开始编译 rootless deb ..."
make clean >/dev/null 2>&1 || true
make package FINALPACKAGE=1

DEB=$(ls -t packages/*.deb 2>/dev/null | head -1)
echo ""
echo "[✓] 编译完成: $DEB"
echo "    把这个 deb 传到手机上, 用 Sileo / Zebra / Filza 安装即可"
