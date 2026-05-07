# OpenClaw Docker 镜像
FROM node:22-slim

# 从 Python 官方镜像拷贝 Python 3.12 (确保使用与 node 镜像一致的 Debian Bookworm 版本)
COPY --from=python:3.12-slim-bookworm /usr/local /usr/local

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV BUN_INSTALL="/usr/local" \
    PATH="/usr/local/bin:$PATH" \
    DEBIAN_FRONTEND=noninteractive

# npm / Playwright 镜像地址（可按需在 build 时覆盖）
ARG NPM_REGISTRY=https://registry.npmmirror.com

# 1. 合并系统依赖安装与全局工具安装，并清理缓存
# 替换 Debian 源为阿里云镜像加速下载
RUN if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
        sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list.d/debian.sources && \
        sed -i 's|http://security.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list.d/debian.sources ; \
    elif [ -f /etc/apt/sources.list ]; then \
        sed -i 's|http://deb.debian.org/debian|http://mirrors.aliyun.com/debian|g' /etc/apt/sources.list && \
        sed -i 's|http://security.debian.org/debian-security|http://mirrors.aliyun.com/debian-security|g' /etc/apt/sources.list ; \
    fi && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    chromium \
    curl \
    docker.io \
    build-essential \
    ffmpeg \
    fonts-liberation \
    fonts-noto-cjk \
    fonts-noto-color-emoji \
    git \
    gosu \
    jq \
    locales \
    openssh-client \
    procps \
    socat \
    tini \
    unzip && \
    sed -i 's/^# *en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen && \
    # update-locale 在部分 slim 基础镜像中会返回 invalid locale settings，这里改为直接写入默认 locale 配置
    printf 'LANG=en_US.UTF-8\nLANGUAGE=en_US:en\nLC_ALL=en_US.UTF-8\n' > /etc/default/locale && \
    # 配置 git 使用 GitHub 加速代理（覆盖 SSH 与 HTTPS）
    git config --system url."https://gh.llkk.cc/https://github.com/".insteadOf https://github.com/ && \
    git config --system url."https://gh.llkk.cc/https://github.com/".insteadOf ssh://git@github.com/ && \
    # 设置 npm 镜像并安装全局包
    npm config set registry ${NPM_REGISTRY} && \
    npm install -g openclaw@latest opencode-ai@latest clawhub playwright playwright-extra puppeteer-extra-plugin-stealth @steipete/bird && \
    # 安装 bun (使用 GitHub 代理)、uv 和 qmd
    curl -fsSL https://gh.llkk.cc/https://raw.githubusercontent.com/oven-sh/bun/main/src/cli/install.sh | GITHUB="https://gh.llkk.cc/https://github.com"  BUN_INSTALL=/usr/local bash && \
    ln -sf /usr/local/bin/python3 /usr/local/bin/python && \
    /usr/local/bin/python3 -m pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ && \
    /usr/local/bin/python3 -m pip install --no-cache-dir uv websockify && \
    npm install -g @tobilu/qmd@latest && \
    # 安装 Playwright 浏览器依赖 (使用 npmmirror 镜像加速)
    npx playwright install chromium --with-deps && \
    # 清理 apt 缓存
    apt-get purge -y --auto-remove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /root/.npm /root/.cache

# 2. 插件安装（作为 node 用户以避免后期权限修复带来的镜像膨胀）
RUN mkdir -p /home/node/.openclaw/workspace /home/node/.openclaw/extensions && \
    chown -R node:node /home/node

USER node
ENV HOME=/home/node
WORKDIR /home/node

# 安装linuxbrew（Homebrew 的 Linux 版本），并配置环境变量
RUN mkdir -p /home/node/.linuxbrew/Homebrew && \
    git clone --depth 1 https://gh.llkk.cc/https://github.com/Homebrew/brew /home/node/.linuxbrew/Homebrew && \
    mkdir -p /home/node/.linuxbrew/bin && \
    ln -s /home/node/.linuxbrew/Homebrew/bin/brew /home/node/.linuxbrew/bin/brew && \
    chown -R node:node /home/node/.linuxbrew && \
    chmod -R g+rwX /home/node/.linuxbrew

ARG CLAWHUB_TOKEN
RUN npm config set registry ${NPM_REGISTRY} && \
  if [ -n "$CLAWHUB_TOKEN" ]; then clawhub login --token "$CLAWHUB_TOKEN"; fi && \
  cd /home/node/.openclaw/extensions && \
  git clone --depth 1 -b NapCat-4.18.1 https://gh.llkk.cc/https://github.com/Daiyimo/openclaw-napcat.git napcat && \
  cd napcat && \
  npm install --production && \
  timeout 300 openclaw plugins install --dangerously-force-unsafe-install -l . || true && \
  cd /home/node/.openclaw/extensions && \
  timeout 300 openclaw plugins install --dangerously-force-unsafe-install @soimy/dingtalk@3.6.1 || true && \
  timeout 300 openclaw plugins install --dangerously-force-unsafe-install @tencent-connect/openclaw-qqbot@1.7.1 || true && \
  timeout 300 openclaw plugins install --dangerously-force-unsafe-install @sunnoy/wecom@3.2.0 || true && \
  mkdir -p /home/node/.openclaw /home/node/.openclaw-seed && \
  # 预执行安装命令（容器内需手动交互，此处仅作声明或环境准备）
  #  printf '{\n  "channels": {\n    "feishu": {\n      "enabled": false,\n      "appId": "2222222222222222",\n      "appSecret": "1111111111111111",\n      "accounts": {\n        "default": {\n          "appId": "2222222222222222",\n          "appSecret": "1111111111111111",\n          "name": "OpenClaw Bot"\n        }\n      }\n    }\n  }\n}\n' > /home/node/.openclaw/openclaw.json && \
  # npx -y @larksuite/openclaw-lark-tools install && \
  find /home/node/.openclaw/extensions -name ".git" -type d -exec rm -rf {} + && \
  mv /home/node/.openclaw/extensions /home/node/.openclaw-seed/ && \
  printf '%s\n' '2026.5.5-f1' > /home/node/.openclaw-seed/extensions/.seed-version && \
  rm -rf /tmp/* /home/node/.npm /home/node/.cache

# 3. 最终配置
USER root

# 复制初始化脚本并确保换行符为 LF
COPY ./init.sh /usr/local/bin/init.sh
RUN sed -i 's/\r$//' /usr/local/bin/init.sh && \
    chmod +x /usr/local/bin/init.sh

# 设置环境变量
ENV HOME=/home/node \
    TERM=xterm-256color \
    NODE_PATH=/usr/local/lib/node_modules \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8 \
    NODE_ENV=production \
    PATH="/home/node/.linuxbrew/bin:/home/node/.linuxbrew/sbin:/usr/local/lib/node_modules/.bin:${PATH}" \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    HOMEBREW_NO_INSTALL_CLEANUP=1

# 暴露端口
EXPOSE 18789

# 设置工作目录为 home
WORKDIR /home/node

# 使用初始化脚本作为入口点
ENTRYPOINT ["/bin/bash", "/usr/local/bin/init.sh"]
