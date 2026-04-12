from typing import Optional

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import unauthorized
from app.core.security import decode_token
from app.models.user import User
from app.repositories.user_repo import UserRepository

http_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(http_bearer),
    db: Session = Depends(get_db),
) -> User:
    if not credentials or not credentials.credentials:
        raise unauthorized()

    payload = decode_token(credentials.credentials)
    if payload.get("token_type") != "access":
        raise unauthorized()

    user_id_str = payload.get("sub")
    if not user_id_str or not str(user_id_str).isdigit():
        raise unauthorized()

    user = UserRepository(db).get_by_id(int(user_id_str))
    if not user:
        raise unauthorized()
    return user

