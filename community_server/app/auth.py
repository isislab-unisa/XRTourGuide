import os
from datetime import datetime, timedelta
from jose import jwt, JWTError
from fastapi import HTTPException, status

SECRET_KEY = os.getenv("JWT_SECRET")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24
REFRESH_TOKEN_EXPIRE_DAYS = 30

def create_access_token(data: dict):
    to_encode = data.copy()
    to_encode["exp"] = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode["type"] = "access"
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(data: dict):
    to_encode = data.copy()
    to_encode["exp"] = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode["type"] = "refresh"
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
