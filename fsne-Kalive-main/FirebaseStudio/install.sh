#!/usr/bin/env sh

PORT="${PORT:-8080}"             # 外部暴露端口，现在由 Xray 监听
UUID="${UUID:-b3a053a4-062e-49fd-f98f-b6014dd7d4a9}"
FALLBACK_PORT="8880"             # 内部 Fallback Web Server 监听端口
PATH_VALUE="/b3a053a4"           # 传输路径

# 假设您的 GitHub 仓库结构和 URL (只需要 index.html 和 Xray 配置)
BASE_URL="https://raw.githubusercontent.com/justlagom/fsne-Kalive/refs/heads/main/FirebaseStudio"
XRAY_CONFIG_URL="$BASE_URL/xray-config-template-fallback.json" # 注意：需要一个新的 Fallback 模板
INDEX_HTML_URL="$BASE_URL/html/index.html" 

# --- 1. 初始化目录 ---
echo "--- 1. Initializing directories ---"
mkdir -p app/xray app/static
cd app

# --- 2. 部署静态 Web 服务器和文件 ---
echo "--- 2. Deploying static web server files ---"
# 下载静态文件
wget -O static/index.html "$INDEX_HTML_URL"

# --- 3. 下载和配置 Xray (核心分流) ---
echo "--- 3. Downloading and configuring Xray ---"
cd xray
# 3.1 下载和解压 Xray
wget https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip Xray-linux-64.zip
rm -f Xray-linux-64.zip

# 3.2 下载 config.json 模板
wget -O config.json "$XRAY_CONFIG_URL"

# 3.3 Xray 配置变量替换
# 替换 Xray 监听的外部端口 $PORT (8080)
sed -i 's/$PORT/'$PORT'/g' config.json
# 替换 UUID
sed -i 's/$UUID/'$UUID'/g' config.json
# 替换 Xray Fallback 目标端口 $FALLBACK_PORT (8880)
sed -i 's/$FALLBACK_PORT/'$FALLBACK_PORT'/g' config.json
# 替换路径 $PATH_VALUE (/b3a053a4)
sed -i 's/$PATH_VALUE/'$PATH_VALUE'/g' config.json 


# --- 4. 启动服务 ---
cd ../.. # 返回到根目录

echo "--- 4. Starting Web Server and Xray ---"

# 4.1 启动 Fallback Web Server (Python)
# 切换到静态文件目录并启动 Python Web Server
echo "Starting Python Fallback Web Server on 127.0.0.1:$FALLBACK_PORT..."
(cd app/static && python3 -m http.server $FALLBACK_PORT > /dev/null 2>&1 &)

# 4.2 启动 Xray
echo "Starting Xray on $PORT..."
app/xray/xray -c app/xray/config.json &


# --- 5. 打印节点信息 ---
echo '---------------------------------------------------------------'
echo "Deployment Complete (using Xray Fallback & Python Web Server)."
echo "Web Page URL: http://localhost:$PORT/"
echo "Xray VLESS Node Path: $PATH_VALUE"
echo "vless://$UUID@example.domain.com:$PORT?encryption=none&security=tls&alpn=http%2F1.1&fp=chrome&type=xhttp&path=$PATH_VALUE&mode=auto#idx-xhttp"
echo '---------------------------------------------------------------'