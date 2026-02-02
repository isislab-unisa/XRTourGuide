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
    """
    Retrieve authenticated user profile details.

    This endpoint returns the profile information of the user
    associated with the provided Bearer access token.

    Authentication:
        Requires an Authorization header with a valid Bearer access token.

    Headers:
        Authorization: Bearer <access_token>

    Token Requirements:
        - Token must be valid
        - Token type must be "access"

    Responses:
        200:
            Description: User profile retrieved successfully.
            Content:
                id: User identifier
                username: Username
                email: Email address
                first_name: First name
                last_name: Last name
                city: City
                description: User description

        401:
            Description: Authorization header missing or invalid token.

        404:
            Description: User not found.
    """
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
    """
    Update authenticated user profile information.

    Updates one or more fields of the authenticated user's profile.
    Only fields provided in the request body will be modified.

    Authentication:
        Requires an Authorization header with a valid Bearer access token.

    Headers:
        Authorization: Bearer <access_token>

    Request Body (JSON):
        email (string, optional): New email address
        firstName (string, optional): New first name
        lastName (string, optional): New last name
        description (string, optional): New profile description

    Token Requirements:
        - Token must be valid
        - Token type must be "access"

    Responses:
        200:
            Description: Profile updated successfully.
            Content:
                message: Confirmation message

        401:
            Description: Authorization header missing or invalid token.

        404:
            Description: User not found.
    """
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
