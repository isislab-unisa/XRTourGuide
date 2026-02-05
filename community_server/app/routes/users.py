from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session

import app.model.models as models
from app.model.database import SessionLocal
from app.auth import verify_token

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# @router.get("/list_users/")
# async def list_users(db: Session = Depends(get_db)):
#     """List all users"""
#     return db.query(models.User).all()

@router.post("/update_password/")
async def update_password(
    db: Session = Depends(get_db),
    request: Request = None
):

    data = await request.json()
    old_password = data.get("oldPassword")
    new_password = data.get("newPassword")
    auth_header = request.headers.get("Authorization")

    if not auth_header:
        raise HTTPException(status_code=401, detail="Authorization header missing")

    try:
        scheme, token = auth_header.split(" ")
        if scheme.lower() != "bearer":
            raise HTTPException(status_code=401, detail="Invalid auth scheme")
    except ValueError:
        raise HTTPException(status_code=401, detail="Invalid Authorization header format")

    payload = verify_token(token)

    if payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="Invalid access token")

    user = db.query(models.User).filter(
        models.User.id == payload["user_id"]
    ).first()

    if not user or not user.verify_password(old_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user.set_password(new_password)
    db.commit()

    return {"message": "Password updated successfully"}


@router.post("/delete_account/")
async def delete_account(
    db: Session = Depends(get_db),
    request: Request = None
):

    data = await request.json()
    password = data.get("password")
    auth_header = request.headers.get("Authorization")

    if not auth_header:
        raise HTTPException(status_code=401, detail="Authorization header missing")

    scheme, _, token = auth_header.partition(" ")

    if scheme.lower() != "bearer" or not token:
        raise HTTPException(status_code=401, detail="Invalid authorization format")

    payload = verify_token(token)

    if payload.get("type") != "access":
        raise HTTPException(status_code=401, detail="Invalid access token")

    user = db.query(models.User).filter(models.User.id == payload["user_id"]).first()
    if not user or not user.verify_password(password):
        raise HTTPException(401, "Invalid credentials")

    user.active = False
    db.commit()
    return {"message": "Account deleted successfully"}
