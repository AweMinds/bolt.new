# 开发模式 Dockerfile - 使用 Vite 开发服务器
FROM node:20-slim

# 安装必要的系统依赖
RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安装 pnpm
RUN corepack enable && corepack prepare pnpm@9.4.0 --activate

WORKDIR /app

# 设置 pnpm 存储目录
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH

# 复制依赖配置文件
COPY package.json pnpm-lock.yaml ./

# 安装依赖（包括 devDependencies）
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

# 复制所有源代码
COPY . .

# 修改 vite.config.ts 添加 server 配置（支持外部访问和跨域隔离）
RUN sed -i '/return {/a\    server: {\n      host: "0.0.0.0",\n      headers: {\n        "Cross-Origin-Opener-Policy": "same-origin",\n        "Cross-Origin-Embedder-Policy": "require-corp",\n      },\n    },' vite.config.ts

# 创建必要的目录
RUN mkdir -p .wrangler/tmp

# 暴露 Vite 开发服务器端口
EXPOSE 5173

# 设置环境变量
ENV NODE_ENV=development

# 启动开发服务器
CMD ["pnpm", "run", "dev"]
