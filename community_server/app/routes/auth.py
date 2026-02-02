import os
from fastapi import APIRouter, Depends, HTTPException, Form, Request
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, JSONResponse
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import secrets
from pydantic import BaseModel, EmailStr
from typing import Optional

from app.auth import create_access_token, create_refresh_token, verify_token
from app.email_utils import send_verification_email, send_forgot_password
from app.model import models
from app.model.database import SessionLocal
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
import httpx

router = APIRouter()

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")
templates = Jinja2Templates(directory=TEMPLATES_DIR)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

class UserRegister(BaseModel):
    """
    User registration request model.

    Represents the payload required to register a new user account.
    """
    username: str
    email: EmailStr
    password: str
    firstName: Optional[str] = None
    lastName: Optional[str] = None
    city: Optional[str] = None
    description: Optional[str] = None

class GoogleLoginRequest(BaseModel):
    """
    Google OAuth login request model.

    Contains the Google ID token returned by the OAuth flow.
    """
    id_token: str

@router.get("/", response_class=HTMLResponse)
async def root(request: Request, db: Session = Depends(get_db)):
    """
    Display login page.

    Renders the login HTML page and loads
    the list of available services.

    Responses:
        200:
            Description: Login page rendered.
            Content: HTML page.
    """
    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        request=request, name="login.html", context={"services": services}
    )

@router.post("/login/", response_class=HTMLResponse)
async def login(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    """
    Web login endpoint.

    Authenticates an administrative user using form data
    and renders the home page on success.

    Form Parameters:
        email (string): User email
        password (string): User password

    Responses:
        200:
            Description: Login successful, home page rendered.
        401:
            Description: Invalid credentials.
    """
    user = db.query(models.User).filter(models.User.email == email).first()

    if not user or not user.verify_password(password) or not user.active or user.role == models.UserRole.USER:
        return templates.TemplateResponse("login.html", {"request": request, "message": "Invalid credentials"})

    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "message": f"Welcome {user.username}!", "services": services}
    )

@router.post("/api/token/")
async def api_login(request: Request, db: Session = Depends(get_db)):
    """
    API login endpoint.

    Authenticates a user and returns JWT access and refresh tokens.

    Request Body (JSON):
        email (string): User email
        password (string): User password

    Responses:
        200:
            Description: Authentication successful.
            Content: JWT tokens and user data.
        400:
            Description: Missing credentials.
        401:
            Description: Invalid credentials or inactive account.
    """
    data = await request.json()
    email = data.get("email")
    password = data.get("password")

    if not email or not password:
        raise HTTPException(status_code=400, detail="Email and password required")

    user = db.query(models.User).filter(models.User.email == email).first()

    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    if not user.active:
        raise HTTPException(status_code=401, detail="Account not active, verify your email")

    if not user.verify_password(password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token({"user_id": user.id})
    refresh_token = create_refresh_token({"user_id": user.id})

    return {
        "access": access_token,
        "refresh": refresh_token,
        "token_type": "bearer",
        "user": {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "name": user.name,
            "surname": user.surname,
            "city": user.city,
            "description": user.description
        }
    }

@router.post("/api/token/refresh/")
async def refresh(request: Request):
    """
    Refresh JWT access token.

    Generates a new access token using a valid refresh token.

    Request Body (JSON):
        refresh (string): Refresh token

    Responses:
        200:
            Description: New access token generated.
        400:
            Description: Invalid refresh token.
    """
    data = await request.json()
    refresh = data.get("refresh")
    payload = verify_token(refresh)

    if payload.get("type") != "refresh":
        raise HTTPException(400, "Invalid refresh token")

    new_access_token = create_access_token({"user_id": payload["user_id"]})

    return {"access": new_access_token}

@router.post("/api/google-login/")
async def google_login(
    data: GoogleLoginRequest,
    db: Session = Depends(get_db)
):
    """
    Authenticate user using Google OAuth.

    Verifies the Google ID token, creates a new user if necessary,
    and returns JWT tokens.

    Request Body (JSON):
        id_token (string): Google OAuth ID token

    Responses:
        200:
            Description: Authentication successful.
        401:
            Description: Invalid Google token or inactive account.
        500:
            Description: Google OAuth configuration or authentication error.
    """
    try:
        GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")

        if not GOOGLE_CLIENT_ID:
            raise HTTPException(status_code=500, detail="Google OAuth not configured")

        idinfo = id_token.verify_oauth2_token(
            data.id_token,
            google_requests.Request(),
            GOOGLE_CLIENT_ID
        )

        if idinfo["iss"] not in ["accounts.google.com", "https://accounts.google.com"]:
            raise HTTPException(status_code=401, detail="Invalid token issuer")

        email = idinfo.get("email")
        given_name = idinfo.get("given_name", "")
        family_name = idinfo.get("family_name", "")
        google_id = idinfo.get("sub")

        if not email:
            raise HTTPException(status_code=400, detail="Email not provided by Google")

        user = db.query(models.User).filter(models.User.email == email).first()

        if not user:
            username = email.split("@")[0]
            base_username = username
            counter = 1
            while db.query(models.User).filter(models.User.username == username).first():
                username = f"{base_username}{counter}"
                counter += 1

            user = models.User(
                username=username,
                email=email,
                name=given_name,
                surname=family_name,
                active=True,
                email_verified=True,
                google_id=google_id,
                role=models.UserRole.USER
            )

            user.set_password(secrets.token_urlsafe(32))
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            if not user.google_id:
                user.google_id = google_id
                db.commit()

            if not user.active:
                raise HTTPException(status_code=401, detail="Account is deactivated")

        access_token = create_access_token({"user_id": user.id})
        refresh_token = create_refresh_token({"user_id": user.id})

        return {
            "access": access_token,
            "refresh": refresh_token,
            "token_type": "bearer",
            "user": {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "name": user.name,
                "surname": user.surname,
                "city": user.city,
                "description": user.description
            }
        }

    except ValueError as e:
        raise HTTPException(status_code=401, detail=f"Invalid Google token: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Authentication error: {str(e)}")

@router.post("/api/verify/")
async def api_verify(token: str = Form(...), db: Session = Depends(get_db)):
    """
    Verify JWT token and return user information.

    Validates a JWT token and returns its payload
    enriched with user profile data.

    Form Parameters:
        token (string): JWT token

    Responses:
        200:
            Description: Token is valid.
        401:
            Description: Invalid token.
    """
    payload = verify_token(token)
    if payload is None:
        return {"valid": False, "status": 401}

    user = db.query(models.User).filter(models.User.id == payload["user_id"]).first()

    payload.update({
        "id": user.id,
        "username": user.username,
        "email": user.email,
        "name": user.name,
        "surname": user.surname,
        "city": user.city,
        "description": user.description,
        "valid": True
    })

    return JSONResponse(content=payload, media_type="application/json")

@router.post("/api_register/")
async def api_register(
    data: UserRegister,
    db: Session = Depends(get_db)
):
    """
    Register a new user account.

    Creates a new inactive user account and sends
    an email verification link.

    Request Body (JSON):
        UserRegister model

    Responses:
        201:
            Description: Account created, verification email sent.
        400:
            Description: Email or username already in use.
        500:
            Description: Email sending or database error.
    """
    existing = db.query(models.User).filter(
        (models.User.email == data.email) |
        (models.User.username == data.username)
    ).first()

    if existing and existing.active:
        raise HTTPException(status_code=400, detail="Email or username already in use")

    if existing and existing.email_verified:
        raise HTTPException(status_code=400, detail="Email already verified")

    email_verification_token = secrets.token_urlsafe(32)
    email_verification_expires = datetime.utcnow() + timedelta(hours=24)

    if existing and not existing.active:
        existing.email_verification_token = email_verification_token
        existing.email_verification_expires = email_verification_expires
        db.commit()

        email_sent = send_verification_email(
            email=data.email,
            token=email_verification_token,
            username=data.username
        )

        if not email_sent:
            db.delete(existing)
            db.commit()
            raise HTTPException(status_code=500, detail="Email sending failed")

        return JSONResponse(
            status_code=201,
            content={"message": "Account created successfully. Please verify your email."}
        )

    user = models.User(
        username=data.username,
        email=data.email,
        name=data.firstName,
        surname=data.lastName,
        city=data.city,
        description=data.description,
        active=False,
        email_verified=False,
        email_verification_token=email_verification_token,
        email_verification_expires=email_verification_expires
    )

    user.set_password(data.password)
    db.add(user)
    db.commit()
    db.refresh(user)

    email_sent = send_verification_email(
        email=data.email,
        token=email_verification_token,
        username=data.username
    )

    if not email_sent:
        db.delete(user)
        db.commit()
        raise HTTPException(status_code=500, detail="Email sending failed")

    return JSONResponse(
        status_code=201,
        content={"message": "Account created successfully. Please verify your email."}
    )

@router.get("/verify-email")
async def verify_email(
    token: str,
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Verify user email address.

    Activates the user account associated with the
    provided email verification token.

    Query Parameters:
        token (string): Email verification token

    Responses:
        200:
            Description: Email verified successfully.
        400:
            Description: Invalid or expired token.
    """
    user = db.query(models.User).filter(
        models.User.email_verification_token == token
    ).first()

    if not user:
        raise HTTPException(status_code=400, detail="Invalid verification token")

    if user.email_verification_expires < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Verification token expired")

    user.email_verified = True
    user.active = True
    user.email_verification_token = None
    user.email_verification_expires = None
    db.commit()

    return templates.TemplateResponse(
        "success.html",
        {"request": request, "message": "Email verified successfully!", "type": "Email"}
    )

@router.post("/resend-verification/")
async def resend_verification(
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Resend email verification link.

    Generates a new verification token and sends it
    to the user's email address.

    Responses:
        200:
            Description: Verification email resent.
        404:
            Description: Email not found.
        400:
            Description: Email already verified.
    """
    data = await request.json()
    email = data.get("email")

    user = db.query(models.User).filter(models.User.email == email).first()

    if not user:
        raise HTTPException(status_code=404, detail="Email not found")

    if user.email_verified:
        raise HTTPException(status_code=400, detail="Email already verified")

    token = secrets.token_urlsafe(32)
    expires = datetime.utcnow() + timedelta(hours=24)

    user.email_verification_token = token
    user.email_verification_expires = expires
    db.commit()

    email_sent = send_verification_email(
        email=user.email,
        token=token,
        username=user.username
    )

    if not email_sent:
        raise HTTPException(status_code=500, detail="Email sending failed")

    return {"message": "Verification email sent again"}

@router.post("/reset-password/")
async def request_reset_password(
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Request password reset email.

    Generates a password reset token and sends
    a reset link to the user's email.

    Responses:
        200:
            Description: Password reset email sent.
        404:
            Description: Email not found.
    """
    data = await request.json()
    email = data.get("email")

    user = db.query(models.User).filter(models.User.email == email).first()

    if not user:
        raise HTTPException(status_code=404, detail="Email not found")

    token = secrets.token_urlsafe(32)
    expires = datetime.utcnow() + timedelta(hours=24)

    user.password_reset_token = token
    user.password_reset_expires = expires
    db.commit()

    email_sent = send_forgot_password(
        email=user.email,
        token=token,
        username=user.username
    )

    if not email_sent:
        user.password_reset_token = None
        user.password_reset_expires = None
        db.commit()
        raise HTTPException(status_code=500, detail="Email sending failed")

    return {"message": "Password reset email sent"}

@router.get("/reset-password/")
def get_reset_form(
    token: str,
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Display password reset form.

    Renders the password reset HTML form
    if the provided token is valid.

    Query Parameters:
        token (string): Password reset token

    Responses:
        200:
            Description: Password reset form rendered.
        400:
            Description: Invalid or expired token.
    """
    user = db.query(models.User).filter(
        models.User.password_reset_token == token
    ).first()

    if not user or user.password_reset_expires < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Invalid or expired token")

    return templates.TemplateResponse(
        "reset_password.html",
        {"request": request, "token": token}
    )

@router.post("/verify-reset-password/")
def verify_reset_password(
    request: Request,
    token: str = Form(...),
    password: str = Form(...),
    confirm_password: str = Form(...),
    db: Session = Depends(get_db)
):
    """
    Verify and complete password reset.

    Validates the reset token and updates the user's password.

    Form Parameters:
        token (string): Password reset token
        password (string): New password
        confirm_password (string): Password confirmation

    Responses:
        200:
            Description: Password successfully updated.
        400:
            Description: Passwords do not match or token invalid.
    """
    if password != confirm_password:
        return templates.TemplateResponse(
            "error.html",
            {"request": request, "message": "Passwords do not match", "type": "Password"},
            status_code=400
        )

    user = db.query(models.User).filter(
        models.User.password_reset_token == token
    ).first()

    if not user or user.password_reset_expires < datetime.utcnow():
        return templates.TemplateResponse(
            "error.html",
            {"request": request, "message": "Invalid or expired token", "type": "Token"},
            status_code=400
        )

    user.set_password(password)
    user.password_reset_token = None
    user.password_reset_expires = None
    db.commit()

    return templates.TemplateResponse(
        "success.html",
        {"request": request, "message": "Password successfully updated!", "type": "Password"}
    )
