#!/bin/bash
#================================================================================
#  iStoreOS RK35XX 本地 Docker 编译脚本 (macOS / Linux)
#
#  用法:
#    ./docker-build.sh              # 首次编译（自动初始化环境 + 编译）
#    ./docker-build.sh rebuild      # 清理后重新全量编译
#    ./docker-build.sh shell        # 进入容器交互式调试
#    ./docker-build.sh save         # 保存容器环境为镜像（加速后续编译）
#    ./docker-build.sh clean        # 删除构建缓存和产物
#    ./docker-build.sh purge        # 删除所有（含源码、镜像）
#
#  环境变量:
#    LAN_IP=192.168.50.1 ./docker-build.sh   # 自定义 LAN 默认 IP
#
#  说明（macOS 用户必读）:
#    OpenWrt 要求大小写敏感文件系统。本脚本将源码放在容器内部（Linux FS），
#    仅将配置文件和 DIY 脚本挂载进去，彻底解决 macOS 的 case-insensitive 问题。
#================================================================================

set -euo pipefail

# ======================== 配置区 ========================
IMAGE_NAME="istoreos-builder"
CONTAINER_NAME="istoreos-build"
VOLUME_NAME="istoreos-openwrt-src"     # 源码持久化卷名（容器内 Linux FS，大小写敏感）
REPO_URL="https://github.com/HarvyYou/istoreos"
REPO_BRANCH="istoreos-24.10"
ARCH="armv8"
LAN_IP="${LAN_IP:-192.168.100.1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# =======================================================

# 颜色输出
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_prereq() {
    command -v docker >/dev/null 2>&1 || error "请先安装 Docker: https://www.docker.com/products/docker-desktop"
    docker info >/dev/null 2>&1 || error "Docker 未运行，请启动 Docker Desktop"
}

# 构建或使用已有的预装镜像
prepare_image() {
    if docker image inspect "${IMAGE_NAME}:latest" &>/dev/null; then
        info "已找到预装环境镜像 ${IMAGE_NAME}:latest"
        return
    fi

    if ! docker image inspect "ubuntu:22.04" &>/dev/null; then
        info "拉取 Ubuntu 22.04 基础镜像..."
        docker pull ubuntu:22.04
    fi

    info "首次使用，正在创建编译环境镜像..."
    docker build --no-cache -t "${IMAGE_NAME}:latest" -f "${SCRIPT_DIR}/Dockerfile.builder" "${SCRIPT_DIR}/"
    info "编译环境镜像创建完成 ✓"
}

# 创建/获取源码持久化卷
prepare_volume() {
    if docker volume inspect "${VOLUME_NAME}" &>/dev/null; then
        return
    fi
    info "创建源码持久化卷 ${VOLUME_NAME}"
    docker volume create "${VOLUME_NAME}" >/dev/null
}

# 在容器内执行命令的通用函数
# 关键：openwrt 源码在 /src（Docker Volume, Linux 大小写敏感FS）
#       项目配置文件挂载到 /work（宿主机目录）
docker_run() {
    docker run --rm -it \
        -e "GITHUB_WORKSPACE=/work" \
        -e "ISTOREOS_LAN_IP=${LAN_IP}" \
        -v "${VOLUME_NAME}:/src" \
        -v "${SCRIPT_DIR}:/work" \
        -w "/src/openwrt" \
        "${IMAGE_NAME}:latest" \
        bash -lc "$1"
}

# 初始化源码（克隆 + feeds + 配置）—— 全在容器内执行
init_source() {
    prepare_volume

    # 检查容器内的源码是否已存在
    local src_exists
    src_exists=$(docker run --rm -v "${VOLUME_NAME}:/src" ubuntu:22.04 bash -c "[ -d /src/openwrt/.git ] && echo YES || echo NO")

    if [ "$src_exists" = "YES" ]; then
        info "OpenWrt 源码已存在于容器卷中，跳过克隆"
    else
        info "正在容器内克隆 iStoreOS 源码 (${REPO_BRANCH}) ..."
        docker run --rm -v "${VOLUME_NAME}:/src" "${IMAGE_NAME}:latest" bash -lc "
            git clone --depth=1 '${REPO_URL}' -b '${REPO_BRANCH}' /src/openwrt
            echo '✅ 克隆完成'
        "
    fi

    info "初始化 Feeds 和配置..."
    docker_run "
        set -e

        # 加载自定义 feeds
        [ -f /work/configfiles/${ARCH}/feeds.conf ] && cp /work/configfiles/${ARCH}/feeds.conf ./feeds.conf || true
        chmod +x /work/diy-part1-6.x.sh
        bash /work/diy-part1-6.x.sh

        # 更新并安装 feeds
        ./scripts/feeds update -a
        ./scripts/feeds install -a

        # 加载 .config 和 DIY Part 2
        cp /work/configfiles/${ARCH}/config_data-6.x.txt .config
        chmod +x /work/diy-part2-6.x.sh
        export GITHUB_WORKSPACE=/work
        export ISTOREOS_LAN_IP='${LAN_IP}'
        bash /work/diy-part2-6.x.sh

        make defconfig
        echo '✅ 源码初始化完成'
    "
}

# 主编译流程
do_build() {
    check_prereq
    info "========================================"
    info " iStoreOS 本地 Docker 编译"
    info " 分支: ${REPO_BRANCH}"
    info " 架构: ${ARCH}"
    info " LAN IP: ${LAN_IP}"
    info "========================================"

    prepare_image
    init_source

    local cpu_count=4
    if command -v sysctl &>/dev/null; then
        cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
    fi
    info "使用 ${cpu_count} 核心并行编译..."

    docker_run "
        set -e
        echo \"LAN IP: \${ISTOREOS_LAN_IP:-${LAN_IP}}\"

        # 下载软件包
        echo ''
        echo '═══ 1/2 下载依赖包 ═══'
        make download -j${cpu_count}

        # 编译固件
        echo ''
        echo '═══ 2/2 编译固件 ═══'
        make -j${cpu_count} || make -j1 V=s

        # 输出结果
        echo ''
        echo '╔══════════════════════════════════════╗'
        echo '║          ✅ 编译完成！                ║'
        echo '╚══════════════════════════════════════╝'

        FW_DIR='bin/targets/*/*'
        if ls \$FW_DIR/*.img.gz &>/dev/null; then
            echo ''
            echo '📦 固件文件:'
            ls -lh \$FW_DIR/*.img.gz | awk '{print \"   \" \$NF \" (\" \$5 \")\"}'
            echo ''
            echo '🎯 Panther X2 固件:'
            ls -lh \$FW_DIR/*panther_x2*.img.gz 2>/dev/null || echo '   (未找到 panther_x2 固件)'
        else
            echo '尝试搜索固件...'
            find bin/targets -name '*.img.gz' -exec ls -lh {} \;
        fi
    "

    # 从容器卷复制产物回宿主机（可选，方便直接访问）
    local out_dir="${SCRIPT_DIR}/firmware_output"
    mkdir -p "$out_dir"
    docker run --rm -v "${VOLUME_NAME}:/src" -v "${out_dir}:/out" ubuntu:22.04 bash -c "
        cp /src/openwrt/bin/targets/*/*/*.img.gz /out/ 2>/dev/null || true
    "

    if [ "$(ls -A "$out_dir" 2>/dev/null)" ]; then
        echo ""
        info "========================================"
        info " 📦 固件已输出到:"
        ls -lh "$out_dir"/*.img.gz 2>/dev/null | awk '{print "  ", $NF}'
        info ""
        info " 目录: ${out_dir}/"
        info "========================================"
    fi
}

# 进入容器交互式 Shell
do_shell() {
    check_prereq
    prepare_image
    prepare_volume

    info "进入容器交互式环境..."
    info "源码位置: /src/openwrt (Docker Volume, 大小写敏感)"
    info "配置文件: /work/ (只读挂载)"
    info "(退出后容器自动删除)"
    echo ""

    docker run --rm -it \
        -e "GITHUB_WORKSPACE=/work" \
        -e "ISTOREOS_LAN_IP=${LAN_IP}" \
        -v "${VOLUME_NAME}:/src" \
        -v "${SCRIPT_DIR}:/work" \
        -w "/src/openwrt" \
        "${IMAGE_NAME}:latest" \
        bash -li
}

# 保存运行中容器为镜像
do_save() {
    check_prereq
    if docker ps -qf "name=${CONTAINER_NAME}" | grep -q .; then
        info "保存容器为镜像 ${IMAGE_NAME}:latest ..."
        docker commit "${CONTAINER_NAME}" "${IMAGE_NAME}:latest"
        info "镜像已保存 ✓ 后续编译将复用此环境"
    else
        warn "没有运行中的 '${CONTAINER_NAME}' 容器"
        info "提示: 先执行 './docker-build.sh shell' 进入容器，"
        info "      再开另一个终端执行 './docker-build.sh save'"
    fi
}

# 清理构建产物（保留源码和 dl 缓存）
do_clean() {
    info "清理编译产物（在容器卷中执行）..."
    docker run --rm -v "${VOLUME_NAME}:/src" ubuntu:22.04 bash -c "
        cd /src/openwrt
        rm -rf bin build_dir staging_dir logs tmp 2>/dev/null
        echo '清理完成 (dl 缓存和 .config 已保留)'
    "
}

# 全量重建
do_rebuild() {
    do_clean
    do_build
}

# 彻底清除（源码卷 + 镜像 + 本地产物）
do_purge() {
    warn "这将删除以下内容:"
    docker volume inspect "${VOLUME_NAME}" &>/dev/null && warn "  - Docker 卷 ${VOLUME_NAME} (源码)"
    docker image inspect "${IMAGE_NAME}:latest" &>/dev/null && warn "  - Docker 镜像 ${IMAGE_NAME}:latest"
    [ -d "${SCRIPT_DIR}/firmware_output" ] && warn "  - ${SCRIPT_DIR}/firmware_output/ (本地固件副本)"
    echo ""
    read -p "确认继续? (y/N): " confirm
    [ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { info "已取消"; return; }

    docker volume rm "${VOLUME_NAME}" 2>/dev/null && info "已删除源码卷"
    docker rmi "${IMAGE_NAME}:latest" 2>/dev/null && info "已删除 Docker 镜像"
    rm -rf "${SCRIPT_DIR}/firmware_output" 2>/dev/null && info "已删除本地固件副本"
    info "清除完成"
}

# 帮助信息
usage() {
    cat <<EOF
iStoreOS RK35XX Docker 本地编译脚本

用法:
  $0                  首次编译（自动初始化 + 编译）
  $0 rebuild          清理后重新全量编译
  $0 shell            进入容器交互式 Shell 调试
  $0 save             保存当前容器为 Docker 镜像
  $0 clean            清理编译产物（保留源码和下载缓存）
  $0 purge            彻底删除源码卷和 Docker 镜像
  $0 help             显示此帮助

环境变量:
  LAN_IP=192.168.50.1 $0    自定义 LAN 口默认 IP

说明 (macOS):
  源码存储在 Docker Volume 中 (Linux 大小写敏感文件系统)
  固件编译完成后自动复制到 ./firmware_output/

示例:
  $0                          # 正常编译
  LAN_IP=192.168.50.1 $0     # 自定义 IP 编译
  $0 shell                   # 进入调试模式
EOF
}

# ======================== 入口 ========================
case "${1:-build}" in
    build|'' )   do_build ;;
    rebuild )    do_rebuild ;;
    shell )      do_shell ;;
    save )       do_save ;;
    clean )      do_clean ;;
    purge )      do_purge ;;
    help|-h|--help ) usage ;;
    * )          error "未知命令: $1\n运行 '$0 help' 查看用法" ;;
esac
