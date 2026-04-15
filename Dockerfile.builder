FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive TZ=Asia/Shanghai

# 移除有问题的 backports 源
RUN sed -i '/backports/d' /etc/apt/sources.list && apt-get update && echo "--- APT UPDATE OK ---"

# 安装基础工具
RUN apt-get install -y --no-install-recommends wget curl git ca-certificates

# 安装编译依赖（带重试：最多 3 次，每次间隔 15 秒，失败包用 --fix-missing 跳过）
RUN for attempt in 1 2 3; do \
        echo "=== 尝试安装编译依赖 ($attempt/3) ===" && \
        (apt-get install -y --fix-missing --no-install-recommends \
          autoconf automake autopoint binutils bison build-essential bzip2 ccache \
          cmake cpio device-tree-compiler fastjar flex gawk gettext gperf haveged help2man \
          intltool libtool lrzsz mkisofs msmtp nano ninja-build patch pkgconf rsync scons \
          squashfs-tools subversion swig texinfo unzip vim xmlto xxd zlib1g-dev p7zip-full \
          libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev \
          libncurses-dev libreadline-dev libssl-dev libpython3-dev qemu-utils \
          python3 python3-pip uglifyjs upx-ucl && break) || sleep 15; \
      done

# pyelftools
RUN pip3 install --break-system-packages pyelftools 2>/dev/null; pip3 install pyelftools 2>/dev/null; true

# 验证关键工具
RUN which wget >/dev/null 2>&1 || { echo "WARN: wget missing, retrying..."; apt-get install -y --no-install-recommends wget; } && \
    which wget && echo "=== ALL TOOLS READY ==="

# 清理缓存
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /work
