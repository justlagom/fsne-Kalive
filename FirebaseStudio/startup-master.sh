#!/usr/bin/env sh

# =================================================================
# 1. 变量定义 (确保与 install.sh 中一致)
# =================================================================
# 使用与 install.sh 中配置相同的固定端口
PORT_XRAY_INTERNAL="8001"
PORT_NGINX_LISTEN="8388"
APP_ROOT_DIR=$(pwd)/app 

# 检查 ARGO_TOKEN 变量，这是启动隧道所必需的
if [ -z "$ARGO_TOKEN" ]; then
    echo "❌ 错误: 环境变量 ARGO_TOKEN 未设置。"
    echo "请在运行脚本前设置: export ARGO_TOKEN='<你的 Cloudflare Tunnel Token>'"
    exit 1
fi


# =================================================================
# 2. 启动 Xray (后台运行)
# =================================================================
echo ">>> 1/4. 启动 Xray 核心 (127.0.0.1:$PORT_XRAY_INTERNAL)..."
# 使用后台运行符 &
"$APP_ROOT_DIR"/xray/xray run -c "$APP_ROOT_DIR"/xray/config.json &
XRAY_PID=$!
echo "   Xray PID: $XRAY_PID"
sleep 2


# =================================================================
# 3. 启动 Nginx (后台运行)
# =================================================================
echo ">>> 2/4. 启动 Nginx 伪装服务器 (localhost:$PORT_NGINX_LISTEN)..."
# Nginx 监听 8388 端口
"$APP_ROOT_DIR"/nginx/nginx -c "$APP_ROOT_DIR"/nginx/nginx.conf &
NGINX_PID=$!
echo "   Nginx PID: $NGINX_PID"
sleep 2


# =================================================================
# 4. 启动 Keepalive (后台运行，通过 nohup 持久化)
# =================================================================
echo ">>> 3/4. 启动 Keepalive Node.js 服务..."
cd "$APP_ROOT_DIR"/idx-keepalive
# 使用 nohup 和 & 确保在终端断开后仍继续运行
nohup npm run start 1>idx-keepalive.log 2>&1 &
KEEPALIVE_PID=$!
echo "   Keepalive PID: $KEEPALIVE_PID"
cd -
sleep 2


# =================================================================
# 5. 启动 Cloudflared Tunnel (主进程，保持在前台运行)
# =================================================================
echo ">>> 4/4. 启动 Cloudflare Argo Tunnel (主进程)..."
echo "   连接到本地 Nginx 端口: $PORT_NGINX_LISTEN"

# Cloudflared 保持在前台运行，作为整个容器/进程组的看门狗
"$APP_ROOT_DIR"/argo/cloudflared tunnel --url http://localhost:$PORT_NGINX_LISTEN --token $ARGO_TOKEN

# 脚本执行到这里意味着 Argo Tunnel 进程已终止
echo "---------------------------------------------------------------"
echo "!!! Cloudflare Argo Tunnel 已终止。正在清理后台进程..."
# 清理所有后台启动的进程
kill $KEEPALIVE_PID $NGINX_PID $XRAY_PID 2>/dev/null
echo "---------------------------------------------------------------"
