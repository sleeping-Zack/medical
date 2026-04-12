<div align="center">
<img width="1200" height="475" alt="GHBanner" src="https://github.com/user-attachments/assets/0aa67016-6eaf-458a-adb2-6e31a0763ed6" />
</div>

# Run and deploy your AI Studio app

This contains everything you need to run your app locally.

View your app in AI Studio: https://ai.studio/apps/1a04488a-9251-4956-a267-216877b0473a

## Run Locally

**Prerequisites:** Node.js；**登录与账号**已改为对接仓库内 `production_stack` 的 **FastAPI + JWT**（需先在本机启动后端，见 `production_stack/README.md`）。用药数据暂存在浏览器 **localStorage**（非云端）。

1. 安装依赖：`npm install`
2. 复制环境变量：将 `.env.example` 复制为 `.env` 或 `.env.local`，按需设置 `VITE_API_BASE_URL`（默认 `http://127.0.0.1:8000`）
3. 若使用 Gemini 功能：在 `.env.local` 中设置 `GEMINI_API_KEY`
4. 启动网页：`npm run dev` → 浏览器打开 [http://127.0.0.1:3000](http://127.0.0.1:3000)

**移动端 / 完整原生体验**请使用 `production_stack/frontend` 的 **Flutter** 应用。
