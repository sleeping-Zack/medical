from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import inspect, text
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.v1.auth import router as auth_router
from app.api.v1.care import router as care_router
from app.core.config import settings
from app.core.database import SessionLocal, engine
from app.models import Base
from app.repositories.user_repo import UserRepository
from app.schemas.common import ApiResponse


def _ensure_users_short_id_column() -> None:
    """旧库缺列时补齐 short_id（create_all 不会 ALTER 已有表结构）。"""
    insp = inspect(engine)
    if "users" not in insp.get_table_names():
        return
    col_names = {c["name"] for c in insp.get_columns("users")}
    if "short_id" in col_names:
        return
    dialect = engine.dialect.name
    with engine.begin() as conn:
        if dialect == "mysql":
            conn.execute(text("ALTER TABLE users ADD COLUMN short_id VARCHAR(6) NULL"))
            conn.execute(text("CREATE UNIQUE INDEX ix_users_short_id ON users (short_id)"))
        elif dialect in {"postgresql", "postgres"}:
            conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS short_id VARCHAR(6) NULL"))
            conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_short_id ON users (short_id)"))
        elif dialect == "sqlite":
            conn.execute(text("ALTER TABLE users ADD COLUMN short_id VARCHAR(6)"))
            conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS ix_users_short_id ON users (short_id)"))


def create_app() -> FastAPI:
    app = FastAPI(title="MedApp API", version="1.0.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(RequestValidationError)
    async def _validation_exception_handler(_: Request, __: RequestValidationError):
        return JSONResponse(status_code=400, content=ApiResponse(code=1001, message="参数校验失败", data=None).model_dump())

    @app.exception_handler(StarletteHTTPException)
    async def _http_exception_handler(_: Request, exc: StarletteHTTPException):
        if isinstance(getattr(exc, "detail", None), dict) and "code" in exc.detail and "message" in exc.detail:
            payload = dict(exc.detail)
            payload["data"] = None
            return JSONResponse(status_code=exc.status_code, content=payload)
        return JSONResponse(
            status_code=exc.status_code,
            content=ApiResponse(code=1001, message=str(exc.detail) if exc.detail else "请求错误", data=None).model_dump(),
        )

    @app.exception_handler(Exception)
    async def _unhandled_exception_handler(_: Request, exc: Exception):
        if settings.debug:
            return JSONResponse(status_code=500, content=ApiResponse(code=1999, message=str(exc), data=None).model_dump())
        return JSONResponse(status_code=500, content=ApiResponse(code=1999, message="服务器异常", data=None).model_dump())

    @app.on_event("startup")
    def _startup():
        Base.metadata.create_all(bind=engine)
        _ensure_users_short_id_column()
        db = SessionLocal()
        try:
            UserRepository(db).backfill_missing_short_ids()
        finally:
            db.close()

    @app.get("/", include_in_schema=False, response_class=HTMLResponse)
    def root():
        return """<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1"/>
  <title>药安心 · 后端服务</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; color: #1e293b; }
    h1 { font-size: 1.25rem; }
    .note { background: #f1f5f9; padding: 1rem; border-radius: 0.5rem; margin: 1rem 0; }
    a { color: #2563eb; }
    ul { padding-left: 1.2rem; }
  </style>
</head>
<body>
  <h1>当前页面是「后端 API」服务（端口 8000）</h1>
  <p>这里只提供接口给 App 调用，<strong>不是</strong>用户日常操作界面。</p>
  <div class="note">
    <strong>要打开你的程序，请选一种：</strong>
    <ul>
      <li><strong>Flutter 客户端（登录注册模块）</strong>：在终端进入 <code>production_stack/frontend</code>，执行 <code>flutter run</code>（会打开模拟器或真机上的 App）。</li>
      <li><strong>仓库根目录的 React 网页（用药提醒）</strong>：在 <code>E:\\medical</code> 执行 <code>npm run dev</code>，浏览器打开 <a href="http://127.0.0.1:3000">http://127.0.0.1:3000</a>。</li>
    </ul>
  </div>
  <p>开发人员调试接口：<a href="/docs">Swagger 文档 /docs</a></p>
</body>
</html>"""

    @app.get("/api/v1/health", response_model=ApiResponse[dict])
    def health():
        return ApiResponse(data={"status": "ok"})

    app.include_router(auth_router)
    app.include_router(care_router)
    return app


app = create_app()
