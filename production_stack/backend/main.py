from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="MedApp API", version="1.0.0")

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class LoginRequest(BaseModel):
    phone: str
    password: str

@app.get("/api/v1/health")
def health_check():
    return {"status": "ok", "message": "FastAPI is running"}

@app.post("/api/v1/auth/login/password")
def login(request: LoginRequest):
    # TODO: Implement actual DB check and JWT generation
    if request.phone == "13800138000" and request.password == "123456":
        return {
            "access_token": "mock_jwt_token",
            "token_type": "bearer"
        }
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Incorrect phone or password",
    )

# TODO: Add Celery tasks, SQLAlchemy models, and MinIO integration
