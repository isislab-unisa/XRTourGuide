import os
from datetime import datetime, timedelta
from jose import jwt, JWTError
from fastapi import HTTPException, status, Depends, Header, Request
from sqlalchemy.orm import Session
from app.model.database import SessionLocal
from app.model.models import Services, User, UserRole
from app.model import models
from typing import Optional
SECRET_KEY = os.getenv("JWT_SECRET")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 30

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

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

def verify_token(token: str, required_type: str = None):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if required_type and payload.get("type") != required_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type"
            )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired"
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials"
        )

async def verify_service_or_mobile(
    request: Request,
    db: Session = Depends(get_db)
) -> models.Services:
    
    x_api_key = request.headers.get("x-api-key") or request.headers.get("X-API-Key")
    x_api_secret = request.headers.get("x-api-secret") or request.headers.get("X-API-Secret")
    x_app_package = request.headers.get("x-app-package") or request.headers.get("X-App-Package")
    
    if x_api_key and x_api_secret:
        service = db.query(models.Services).filter(
            models.Services.api_key == x_api_key,
            models.Services.active == True
        ).first()
        
        if service:
            is_valid = service.verify_secret(x_api_secret)
            
            if is_valid:
                return service
    
    if x_app_package:
        service = db.query(models.Services).filter(
            models.Services.domain == x_app_package,
            models.Services.active == True,
            models.Services.api_key == None
        ).first()
        
        if service:
            return service
    
    raise HTTPException(
        status_code=403,
        detail="Unauthorized: invalid service credentials or app package"
    )

async def get_current_user(
    authorization: str = Header(...),
    db: Session = Depends(get_db)
) -> User:
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication scheme"
        )
    
    token = authorization.split(" ")[1]
    payload = verify_token(token, required_type="access")
    
    username = payload.get("username")
    if not username:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload"
        )
    
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    
    return user

def get_current_user_from_session(request: Request, db: Session = Depends(get_db)) -> models.User:
    user_id = request.session.get("user_id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    
    return user