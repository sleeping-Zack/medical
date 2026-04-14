# 药安心 MVP - 本地化登录注册模块

这是一个完整的「家属端 + 老人端」登录注册基础工程，满足：

- **日常开发前端**：仓库根目录 **Vite + React**（`npm run dev`，默认 <http://127.0.0.1:3000>）
- **可选移动端**：`production_stack/frontend` 为 **Flutter** + Riverpod + go_router
- FastAPI + MySQL + Redis
- JWT（access token + refresh token）
- 中国大陆手机号 + 短信验证码 + 密码
- 短信服务抽象（Mock / 阿里云 SendSms 已用签名 HTTP 接入 / 腾讯云占位）

## 功能清单

- 注册：手机号 + 短信验证码 + 设置密码 + 角色（`personal` / `elderly`）
- 登录：
  - 手机号 + 密码
  - 手机号 + 短信验证码
- 找回密码：手机号 + 短信验证码 + 重置密码
- 自动登录恢复：App 启动先校验 access token，失败后自动 refresh
- 验证码安全策略：
  - 6 位数字
  - Redis 缓存 5 分钟
  - 60 秒冷却
  - 每小时最多 5 次
  - 每天最多 10 次
  - 验证成功即失效

## 工程结构

```text
medical/（仓库根目录）
  package.json              # Web 前端依赖与 npm run dev
  src/                      # React 页面与业务（看护端 / 长辈端 Web）
  vite.config.ts
production_stack/
  backend/
    app/
      api/
        deps.py
        v1/
          auth.py                  # /api/v1/auth/* 路由
      core/
        config.py                  # 配置
        database.py                # MySQL Session
        redis_client.py            # Redis 客户端
        security.py                # JWT/密码/验证码安全逻辑
        errors.py                  # 统一错误
      models/
        user.py                    # User 模型
        sms_code_log.py            # SmsCodeLog 模型
      repositories/
        user_repo.py
        sms_log_repo.py
      schemas/
        auth.py
        common.py
      services/
        auth_service.py
        sms_code_service.py
        sms_service.py             # SmsService + Mock/Tencent/Aliyun
      utils/
        validators.py              # 手机号/密码/验证码校验
      main.py
    .env.example
    requirements.txt
    Dockerfile
    main.py
  frontend/
    lib/
      core/
        api/api_client.dart
        storage/token_storage.dart
        providers.dart
      features/
        splash/splash_page.dart
        auth/
          models/
          providers/
          repositories/
          pages/
            login_page.dart
            register_page.dart
            forgot_password_page.dart
        home/home_page.dart
      routing/app_router.dart
      shared/
        validators.dart
        ui/app_theme.dart
      app.dart
      main.dart
    pubspec.yaml
  docker-compose.yml
```

## 后端启动（先后端）

### 方式 A：Docker Compose（推荐）

在仓库根目录执行：

```bash
cd production_stack
docker compose up --build
```

服务：

- API: http://127.0.0.1:8000/docs
- MySQL: 127.0.0.1:3307（默认，避免占用本机 3306）
- Redis: 127.0.0.1:6380（默认，避免占用本机 6379）

如需自定义端口，可在启动前设置环境变量：

```bash
set MYSQL_HOST_PORT=3308
set REDIS_HOST_PORT=6381
set API_HOST_PORT=8001
docker compose up --build
```

### 方式 B：本机启动（不用 Docker）

**1）安装并启动 MySQL 8；Redis 可选**

- MySQL 监听 **3306**（与 `backend/.env.example` 一致）。
- **Redis**：若本机 **未安装 / 未启动** Redis，在 `backend/.env` 中设置 **`REDIS_USE_MOCK=true`**，将使用 **内存模拟**（`fakeredis`，仅适合开发；验证码与 token 在重启 API 后会丢失）。已安装 Redis 则保持 `REDIS_USE_MOCK=false`，并保证 **6379** 可连。
- 在 MySQL 中创建库与用户（示例账号与 `.env` 一致，可按需改密码并同步改 `MYSQL_DSN`）：

```sql
CREATE DATABASE IF NOT EXISTS medapp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'medapp'@'localhost' IDENTIFIED BY 'medapp_pwd';
GRANT ALL PRIVILEGES ON medapp.* TO 'medapp'@'localhost';
FLUSH PRIVILEGES;
```

（若 `CREATE USER` 提示用户已存在，可删掉该行，只保留 `GRANT`。）

若你的 MySQL 只允许 `root` 登录，可把 `MYSQL_DSN` 改成 `root:你的密码@127.0.0.1:3306/medapp`。

**2）后端（FastAPI）**

```powershell
cd production_stack/backend
python -m venv .venv
.\.venv\Scripts\activate
$env:ALL_PROXY=''
pip install -r requirements.txt
copy .env.example .env
# 按需编辑 .env：MYSQL_DSN；无 Redis 时设 REDIS_USE_MOCK=true
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

**务必使用上面虚拟环境里的 Python**（已执行 `activate` 后提示符前有 `(.venv)`）。若直接用 Anaconda / 系统全局的 `python` 启动，会报 **`ModuleNotFoundError: No module named 'pydantic_settings'`** 等缺包错误。可不激活环境，强制指定解释器：

```powershell
.\.venv\Scripts\python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

首次启动会在库里 **自动建表**（`create_all`）。文档：<http://127.0.0.1:8000/docs>。

若报 `ValidationError: mysql_dsn Field required`，说明 **没有 `.env`** 或当前目录不对；确认在 `production_stack/backend` 下存在 `.env`。

**3）前端（Vite + React，推荐）**

在**仓库根目录**（含有 `package.json` 与 `production_stack/` 的那一层，即 `medical/`）执行。  
若你上一步还在 `production_stack/backend`，需先回到根目录（PowerShell 下为 `cd ..\..`）：

```bash
cd ../..
npm install
npm run dev
```

浏览器打开：<http://127.0.0.1:3000>（脚本中为 `--port=3000 --host=0.0.0.0`）。  
请求后端 API 默认指向 `http://127.0.0.1:8000`；若需改地址，在仓库根目录 `.env` 中设置 `VITE_API_BASE_URL`。

**可选：Flutter 客户端**（`production_stack/frontend`）

```powershell
cd production_stack/frontend
flutter pub get
flutter run
```

模拟器访问本机后端时可使用：

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## 真实短信（阿里云）

1. 在 [阿里云短信服务控制台](https://dysms.console.aliyun.com/) 开通服务，创建 **短信签名** 与 **验证码模板**（模板内需有一个变量，例如 `${code}`，对应配置项里的占位符名）。
2. 创建 RAM 子账号或使用主账号，为其生成 **AccessKey**（勿提交到仓库），并确保有 `SendSms` 权限。
3. 在 `production_stack/backend/.env` 中设置：
   - `SMS_PROVIDER=aliyun`
   - `ALIYUN_SMS_ACCESS_KEY_ID`、`ALIYUN_SMS_ACCESS_KEY_SECRET`
   - `ALIYUN_SMS_SIGN_NAME`、`ALIYUN_SMS_TEMPLATE_CODE`（与控制台一致）
   - 若模板变量名不是 `code`，设置 `ALIYUN_SMS_TEMPLATE_PARAM_KEY` 与模板一致。
4. **生产环境** 建议同时设置 `APP_ENV=production`、`DEBUG=false`，这样 `/api/v1/auth/sms/send` 的响应里 **不会** 再带 `debug_code`。
5. 若第三方发送失败，后端会 **回滚** 本次 Redis 冷却/计数与数据库中的待验证日志，避免「没收到短信却进入冷却」。

腾讯云：`SMS_PROVIDER=tencent` 仍为占位，需自行接入 SDK 或 HTTP 后再用。

## 后端接口（8 个接口 + mock 示例）

### 发送验证码

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/sms/send ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13800138000\",\"scene\":\"register\"}"
```

示例返回（开发环境会带 debug_code）：

```json
{"code":0,"message":"ok","data":{"cooldown_seconds":60,"debug_code":"123456"}}
```

### 注册

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/register ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13800138000\",\"code\":\"123456\",\"password\":\"abc12345\",\"role\":\"personal\"}"
```

示例返回：

```json
{"code":0,"message":"ok","data":{"access_token":"...","refresh_token":"...","token_type":"bearer","expires_in":1800}}
```

### 登录（密码）

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/login/password ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13800138000\",\"password\":\"abc12345\"}"
```

示例返回：

```json
{"code":0,"message":"ok","data":{"access_token":"...","refresh_token":"...","token_type":"bearer","expires_in":1800}}
```

### 登录（短信）

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/login/sms ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13800138000\",\"code\":\"123456\"}"
```

示例返回：

```json
{"code":0,"message":"ok","data":{"access_token":"...","refresh_token":"...","token_type":"bearer","expires_in":1800}}
```

### 重置密码

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/password/reset ^
  -H "Content-Type: application/json" ^
  -d "{\"phone\":\"13800138000\",\"code\":\"123456\",\"new_password\":\"abc12345\"}"
```

示例返回：

```json
{"code":0,"message":"ok","data":null}
```

### 获取当前用户

```bash
curl http://127.0.0.1:8000/api/v1/auth/me ^
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

示例返回：

```json
{"code":0,"message":"ok","data":{"id":1,"phone":"13800138000","role":"personal"}}
```

### 刷新 Token

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/refresh ^
  -H "Content-Type: application/json" ^
  -d "{\"refresh_token\":\"YOUR_REFRESH_TOKEN\"}"
```

示例返回：

```json
{"code":0,"message":"ok","data":{"access_token":"...","refresh_token":"...","token_type":"bearer","expires_in":1800}}
```

### 退出登录

```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/logout ^
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" ^
  -H "Content-Type: application/json" ^
  -d "{}"
```

示例返回：

```json
{"code":0,"message":"ok","data":null}
```

## 前端启动

### Web（默认）

在仓库根目录执行：

```bash
npm install
npm run dev
```

访问 <http://127.0.0.1:3000>。后端地址默认 `http://127.0.0.1:8000`，可在根目录 `.env` 配置 `VITE_API_BASE_URL`。

### Flutter（可选）

代码位于 `production_stack/frontend/lib/`。若缺少 `android/`、`ios/` 等平台目录，可在 `production_stack/frontend/` 下执行一次 `flutter create .`，再：

```bash
flutter pub get
flutter run
```

默认 API 为 `http://127.0.0.1:8000`，模拟器可用：

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## 安全说明

- 密码：`passlib+bcrypt` 哈希存储
- JWT：Bearer 鉴权，access/refresh 分离
- refresh token：Redis 存储 jti，支持失效控制
- 验证码：hash 后存储，校验成功立即失效
- 防轰炸：短信发送频率限制（冷却/小时/天）
- 防爆破：密码登录失败次数限制（短时间封禁）

## 扩展点（为“家属绑定老人”预留）

- 验证码 `scene` 已包含 `bind`
- `SmsCodeLog` 已记录 `device_id`、`ip`，便于后续风控
- 可在现有 `auth` 基础上新增 `binding` 领域模型与 API（邀请码、关系确认、权限范围）
