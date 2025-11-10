#!/bin/bash

# MathModelAgent 一键启动脚本
# 作者: Cline AI Assistant
# 功能: 自动启动后端和前端服务，并自动打开浏览器

echo "================================================"
echo "      MathModelAgent 一键启动脚本"
echo "================================================"

# 检查 Redis 是否运行
echo "检查 Redis 服务..."
if ! redis-cli ping > /dev/null 2>&1; then
    echo "❌ Redis 服务未运行，请先启动 Redis"
    echo "启动命令: redis-server"
    exit 1
fi
echo "✅ Redis 服务正常运行"

# 检查端口占用情况
check_port() {
    local port=$1
    local service=$2
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
        echo "⚠️  $service 端口 $port 已被占用，尝试停止现有进程..."
        pkill -f "uvicorn app.main:app" 2>/dev/null || true
        sleep 2
        # 再次检查
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null ; then
            echo "❌ 无法释放 $service 端口 $port，请手动关闭占用该端口的进程"
            exit 1
        fi
    fi
}

# 检查后端端口
check_port 8000 "后端服务"

# 启动后端服务
echo "启动后端服务..."
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
BACKEND_PID=$!
cd ..

# 等待后端服务启动
echo "等待后端服务启动..."
sleep 5

# 检查后端是否正常启动
if ! curl -s http://localhost:8000/ > /dev/null; then
    echo "❌ 后端服务启动失败，尝试重新启动..."
    kill $BACKEND_PID 2>/dev/null || true
    sleep 2
    cd backend
    python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
    BACKEND_PID=$!
    cd ..
    sleep 5
    
    if ! curl -s http://localhost:8000/ > /dev/null; then
        echo "❌ 后端服务仍然无法启动，请检查错误信息"
        exit 1
    fi
fi
echo "✅ 后端服务启动成功 (PID: $BACKEND_PID)"

# 检查前端端口
check_port 5173 "前端服务"

# 启动前端服务
echo "启动前端服务..."
cd frontend
pnpm install --silent
pnpm run dev &
FRONTEND_PID=$!
cd ..

# 等待前端服务启动
echo "等待前端服务启动..."
sleep 10

# 检查前端是否正常启动
if ! curl -s http://localhost:5173/ > /dev/null; then
    echo "❌ 前端服务启动失败"
    kill $FRONTEND_PID 2>/dev/null || true
    exit 1
fi
echo "✅ 前端服务启动成功 (PID: $FRONTEND_PID)"

# 自动打开浏览器
echo "自动打开浏览器..."
if command -v open > /dev/null; then
    # macOS
    open http://localhost:5173/
elif command -v xdg-open > /dev/null; then
    # Linux
    xdg-open http://localhost:5173/
elif command -v start > /dev/null; then
    # Windows (Git Bash)
    start http://localhost:5173/
else
    echo "⚠️  无法自动打开浏览器，请手动访问: http://localhost:5173/"
fi

echo ""
echo "================================================"
echo "          服务启动完成！"
echo "================================================"
echo "前端界面: http://localhost:5173/"
echo "后端API:  http://localhost:8000/"
echo ""
echo "服务状态监控:"
echo "- 后端服务 PID: $BACKEND_PID"
echo "- 前端服务 PID: $FRONTEND_PID"
echo ""
echo "停止服务命令:"
echo "kill $BACKEND_PID $FRONTEND_PID"
echo "================================================"

# 设置信号处理，优雅关闭服务
cleanup() {
    echo ""
    echo "正在停止服务..."
    kill $BACKEND_PID 2>/dev/null || true
    kill $FRONTEND_PID 2>/dev/null || true
    echo "服务已停止"
    exit 0
}

trap cleanup SIGINT SIGTERM

# 保持脚本运行，监控服务状态
echo "服务运行中... 按 Ctrl+C 停止服务"
while true; do
    # 检查后端服务是否存活
    if ! kill -0 $BACKEND_PID 2>/dev/null; then
        echo "❌ 后端服务异常退出，正在重新启动..."
        cd backend
        python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
        BACKEND_PID=$!
        cd ..
        echo "✅ 后端服务已重新启动 (PID: $BACKEND_PID)"
    fi
    
    # 检查前端服务是否存活
    if ! kill -0 $FRONTEND_PID 2>/dev/null; then
        echo "❌ 前端服务异常退出，正在重新启动..."
        cd frontend
        pnpm run dev &
        FRONTEND_PID=$!
        cd ..
        echo "✅ 前端服务已重新启动 (PID: $FRONTEND_PID)"
    fi
    
    sleep 10
done
