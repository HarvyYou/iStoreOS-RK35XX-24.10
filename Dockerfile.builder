FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive TZ=Asia/Shanghai

# 移除有问题的 backports 源，保留官方 main + updates + security
RUN sed -i '/backports/d' /etc/apt/sources.list && \
    cat /etc/apt/sources.list && \
    apt-get update && echo "--- APT UPDATE OK ---"

# 安装基础工具
RUN apt-get install -y --no-install-recommends wget curl git ca-certificates

# 安装编译依赖
RUN apt-get install -y --no-install-recommends \
      autoconf automake autopoint binutils bison build-essential bzip2 ccache \
      cmake cpio device-tree-compiler fastjar flex gawk gettext gperf haveged help2man \
      intltool libtool lrzsz mkisofs msmtp nano ninja-build patch pkgconf rsync scons \
      squashfs-tools subversion swig texinfo unzip vim xmlto xxd zlib1g-dev p7zip-full \
      libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev \
      libncurses-dev libreadline-dev libssl-dev libpython3-dev qemu-utils \
      python3 python3-pip uglifyjs upx-ucl

# pyelftools
RUN pip3 install --break-system-packages pyelftools || pip3 install pyelftools || true

# 验证
RUN which wget && wget --version | head -1 && echo "=== ALL TOOLS READY ==="

# 清理缓存
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /work
