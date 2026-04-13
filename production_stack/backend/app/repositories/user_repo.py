import random
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.user import User


class UserRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_phone(self, phone: str) -> Optional[User]:
        return self.db.execute(select(User).where(User.phone == phone)).scalar_one_or_none()

    def get_by_id(self, user_id: int) -> Optional[User]:
        return self.db.get(User, user_id)

    def get_by_short_id(self, short_id: str) -> Optional[User]:
        return self.db.execute(select(User).where(User.short_id == short_id)).scalar_one_or_none()

    def allocate_short_id(self) -> str:
        for _ in range(300):
            s = f"{random.randint(0, 999999):06d}"
            exists = self.db.execute(select(User.id).where(User.short_id == s)).first()
            if exists is None:
                return s
        raise RuntimeError("无法生成唯一绑定短号")

    def create(self, *, phone: str, password_hash: str, role: str) -> User:
        user = User(phone=phone, password_hash=password_hash, role=role, is_phone_verified=True)
        self.db.add(user)
        self.db.flush()
        user.short_id = self.allocate_short_id()
        self.db.commit()
        self.db.refresh(user)
        return user

    def ensure_short_id(self, user: User) -> User:
        if user.short_id:
            return user
        user.short_id = self.allocate_short_id()
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def backfill_missing_short_ids(self) -> int:
        users = list(self.db.execute(select(User).where(User.short_id.is_(None))).scalars().all())
        n = 0
        for u in users:
            u.short_id = self.allocate_short_id()
            self.db.add(u)
            n += 1
        if n:
            self.db.commit()
        return n

    def update_password(self, *, user: User, password_hash: str) -> User:
        user.password_hash = password_hash
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user
