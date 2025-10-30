# 使用多阶段构建来优化镜像大小
# 使用 Debian slim 版本而不是 Alpine，因为 Cloudflare workerd 需要 glibc
FROM node:20-slim AS base

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

# ===========================
# Dependencies stage
# ===========================
FROM base AS deps

# 复制依赖配置文件
COPY package.json pnpm-lock.yaml ./

# 安装所有依赖（包括 devDependencies，构建时需要）
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

# ===========================
# Build stage
# ===========================
FROM base AS build

# 复制依赖
COPY --from=deps /app/node_modules ./node_modules

# 复制源代码
COPY . .

# 构建应用
RUN pnpm run build

# ===========================
# Production stage
# ===========================
FROM base AS runner

# 设置环境变量
ENV NODE_ENV=production

# 创建非 root 用户（Debian 语法）
RUN groupadd --system --gid 1001 nodejs && \
    useradd --system --uid 1001 -g nodejs -m remix

# 复制必要的文件
COPY --from=build --chown=remix:nodejs /app/build ./build
COPY --from=build --chown=remix:nodejs /app/public ./public
COPY --from=build /app/node_modules ./node_modules
COPY --chown=remix:nodejs package.json pnpm-lock.yaml ./
COPY --chown=remix:nodejs bindings.sh ./
COPY --chown=remix:nodejs wrangler.toml ./
COPY --chown=remix:nodejs load-context.ts ./
COPY --chown=remix:nodejs worker-configuration.d.ts ./

# 确保 bindings.sh 可执行
RUN chmod +x bindings.sh

# 创建 Cloudflare Pages worker 文件以连接服务端代码
RUN echo 'import * as remixBuild from "../server/index.js";\n\
import { createRequestHandler } from "@remix-run/cloudflare";\n\
\n\
const handleRequest = createRequestHandler(remixBuild);\n\
\n\
export default {\n\
  async fetch(request, env, ctx) {\n\
    try {\n\
      const loadContext = {\n\
        cloudflare: {\n\
          env,\n\
          ctx,\n\
        },\n\
      };\n\
      return await handleRequest(request, loadContext);\n\
    } catch (error) {\n\
      console.error(error);\n\
      return new Response("Internal Error", { status: 500 });\n\
    }\n\
  },\n\
};' > build/client/_worker.js

# 创建 _routes.json 配置静态资源路由
RUN echo '{\n\
  "version": 1,\n\
  "include": ["/*"],\n\
  "exclude": ["/assets/*", "/*.ico", "/*.png", "/*.svg", "/*.jpg", "/*.jpeg", "/*.gif", "/*.webp"]\n\
}' > build/client/_routes.json

# 创建 wrangler 需要的目录并设置整个应用目录的权限
RUN mkdir -p .wrangler/tmp && \
    chown -R remix:nodejs /app

# 切换到非 root 用户
USER remix

# 暴露端口（wrangler pages dev 使用 8788）
EXPOSE 8788

# 启动应用（生产模式，监听 0.0.0.0 以允许外部访问）
CMD ["pnpm", "run", "start"]
