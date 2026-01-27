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

@router.get("/profile_detail/")
def api_profile_detail(request: Request, db: Session = Depends(get_db)):
    """Get user profile details"""
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

    if not user:
        raise HTTPException(404, "User not found")

    return {
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "first_name": user.name,
        "last_name": user.surname,
        "city": user.city,
        "description": user.description
    }

@router.post("/update_profile/")
async def update_profile(
    db: Session = Depends(get_db),
    request: Request = None
):
    """Update user profile information"""
    data = await request.json()
    
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

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    print(f"User: ", user)
    user.email = data.get("email", user.email)
    user.name = data.get("firstName", user.name)
    user.surname = data.get("lastName", user.surname)
    user.description = data.get("description", user.description)

    db.commit()

    return {"message": "Profile updated successfully"}