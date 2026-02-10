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

@router.get(
    "/profile_detail/",
    summary="Retrieve authenticated user profile details",
    responses={
        200: {
            "description": "User profile retrieved successfully",
            "content": {
                "application/json": {
                    "example": {
                        "id": 1,
                        "username": "johndoe",
                        "email": "john@example.com",
                        "first_name": "John",
                        "last_name": "Doe",
                        "city": "New York",
                        "description": "Software developer"
                    }
                }
            }
        },
        401: {"description": "Authorization header missing or invalid"},
        404: {"description": "User not found"}
    }
)
def api_profile_detail(request: Request, db: Session = Depends(get_db)):
    
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

@router.post(
    "/update_profile/",
    summary="Update authenticated user profile",
    responses={
        200: {
            "description": "Profile updated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "message": "Profile updated successfully"
                    }
                }
            }
        },
        401: {"description": "Authorization header missing or invalid"},
        404: {"description": "User not found"}
    }
)
async def update_profile(
    db: Session = Depends(get_db),
    request: Request = None
):
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

    user.email = data.get("email", user.email)
    user.name = data.get("firstName", user.name)
    user.surname = data.get("lastName", user.surname)
    user.description = data.get("description", user.description)

    db.commit()

    return {"message": "Profile updated successfully"}