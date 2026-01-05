import sys, os
from fastapi import Request
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException, Form
from sqlalchemy.orm import Session
import model.models as models
from model.database import SessionLocal, engine
import dotenv
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.requests import Request as FastAPIRequest
import httpx
from .auth import create_access_token, create_refresh_token, verify_token
from pydantic import BaseModel
from fastapi import FastAPI, Depends, HTTPException, Body, Form
from fastapi import Request
from .email_utils import *
from fastapi import HTTPException, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import secrets
from pydantic import BaseModel, EmailStr
from typing import Optional
from fastapi.middleware.cors import CORSMiddleware

dotenv.load_dotenv()

models.Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(app: FastAPI):
    db = SessionLocal()
    try:
        default_name = os.getenv("DEFAULT_USER_NAME")
        default_email = os.getenv("DEFAULT_USER_EMAIL")
        default_password = os.getenv("DEFAULT_USER_PASSWORD")

        if default_name and default_email and default_password:
            existing_user = db.query(models.User).filter(models.User.email == default_email).first()
            if not existing_user:
                new_user = models.User(
                    username=default_name,
                    email=default_email,
                    role = models.UserRole.ADMIN,
                    active = True,
                    name = default_name,
                    surname = default_name,
                    description = default_name,
                    city = default_name,
                )
                new_user.set_password(default_password)
                db.add(new_user)
                print("Utente di default aggiunto")
            else:
                print("Utente di default già presente")
        else:
            print("Variabili di default utente non settate")

        db.commit()
        yield
    finally:
        db.close()

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost", "http://127.0.0.1", "https://xrtourguide.di.unisa.it"],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEMPLATES_DIR = os.path.join(BASE_DIR, "templates")

templates = Jinja2Templates(directory=TEMPLATES_DIR)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/", response_class=HTMLResponse)
async def root(request: FastAPIRequest, db: Session = Depends(get_db)):
    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        request=request, name="login.html", context={"services": services}
    )

@app.get("/list_services/")
async def list_services(db: Session = Depends(get_db)):
    return db.query(models.Services).all()

@app.get("/list_users/")
async def list_users(db: Session = Depends(get_db)):
    return db.query(models.User).all()

@app.post("/login/", response_class=HTMLResponse)
async def login(
    request: FastAPIRequest,
    email: str = Form(...),
    password: str = Form(...),
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(models.User.email == email).first()

    if not user or not user.verify_password(password) or not user.active or user.role == models.UserRole.USER:
        return templates.TemplateResponse("login.html", {"request": request, "message": "Invalid credentials"})

    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "message": f"Welcome {user.username}!", "services": services})

@app.get("/register_service")
def register_service(request: Request):
    return templates.TemplateResponse(
        "register_service.html",
        {"request": request}
    )

@app.post("/add_service/")
def add_service(
    request: Request,
    name: str = Form(...),
    domain: str = Form(...),
    active: bool = Form(...),
    db: Session = Depends(get_db)
):
    new_service = models.Services(name=name, domain=domain, active=active)
    db.add(new_service)
    db.commit()
    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "services": services,}
    )

@app.post("/delete_service/{service_id}")
def delete_service(service_id: int, request: Request, db: Session = Depends(get_db)):
    service = db.query(models.Services).filter(models.Services.id == service_id).first()
    if not service:
        raise HTTPException(status_code=404, detail="Service not found")
    db.delete(service)
    db.commit()

    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "services": services, "message": "Service deleted successfully"}
    )

@app.post("/status_service/{service_id}")
def status_service(service_id: int, request: Request, db: Session = Depends(get_db)):
    service = db.query(models.Services).filter(models.Services.id == service_id).first()
    if not service:
        raise HTTPException(status_code=404, detail="Service not found")
    
    service.active = not service.active
    db.commit()

    services = db.query(models.Services).all()
    return templates.TemplateResponse(
        "home.html",
        {"request": request, "services": services, "message": "Service status updated"}
    )

@app.get("/get_services/")
async def get_services(db: Session = Depends(get_db)):
    services = db.query(models.Services).filter(models.Services.active == True).all()

    async with httpx.AsyncClient() as client:
        results = []
        for s in services:
            try:
                r = await client.get(f"https://{s.domain}/health_check/")
                if r.status_code == 200:
                    results.append(s)
            except Exception:
                pass

    return results

@app.get("/get_service/{service_id}")
async def get_service(service_id: int, db: Session = Depends(get_db)):
    return db.query(models.Services).filter(models.Services.id == service_id).first().domain

@app.post("/api/token/")
async def api_login(request: Request, db: Session = Depends(get_db)):
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
    
    if not user or not user.verify_password(password):
        raise HTTPException(status_code=401, detail=f"Invalid credentials")
    
    
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

@app.post("/api/token/refresh/")
async def refresh(request:Request):
    data = await request.json()
    refresh = data.get("refresh")
    payload = verify_token(refresh)
    if payload.get("type") != "refresh":
        raise HTTPException(400, "Invalid refresh token")

    new_access_token = create_access_token({"user_id": payload["user_id"]})

    return {"access": new_access_token}

@app.post("/api/verify/")
async def api_verify(token: str = Form(...), db: Session = Depends(get_db)):
    payload = verify_token(token)
    if payload is None:
        return {"valid": False, "status": 401}

    user = db.query(models.User).filter(models.User.id == payload["user_id"]).first()

    payload["id"] = user.id
    payload["username"] = user.username
    payload["email"] = user.email
    payload["name"] = user.name
    payload["surname"] = user.surname
    payload["city"] = user.city
    payload["description"] = user.description
    payload['valid'] = True

    return JSONResponse(content=payload, media_type="application/json")

@app.post("/update_password/")
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

@app.post("/delete_account/")
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

@app.get("/profile_detail/")
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

@app.post("/update_profile/")
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

    print(f"User: ", user)
    # user.username = data.get("username", user.username)
    user.email = data.get("email", user.email)
    user.name = data.get("firstName", user.name)
    user.surname = data.get("lastName", user.surname)
    # user.city = data.get("city", user.city)
    user.description = data.get("description", user.description)

    db.commit()

    return {"message": "Profile updated successfully"}

class UserRegister(BaseModel):
    username: str
    email: EmailStr
    password: str
    firstName: Optional[str] = None
    lastName: Optional[str] = None
    city: Optional[str] = None
    description: Optional[str] = None

@app.post("/api_register/")
async def api_register(
    data: UserRegister,
    db: Session = Depends(get_db)
):
    existing = db.query(models.User).filter(
        (models.User.email == data.email) |
        (models.User.username == data.username)
    ).first()

    if existing and existing.active:
        raise HTTPException(
            status_code=400,
            detail="Email o username già in uso"
        )

    if existing and existing.email_verified:
        raise HTTPException(
            status_code=400,
            detail="Email già verificata"
        )
    
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
            raise HTTPException(
                status_code=500,
                detail="Errore nell'invio dell'email di verifica"
            )
    
        return JSONResponse(
            status_code=201,
            content={"message": "Account creato con successo! Verifica la tua email per attivare il tuo account."}
        )
    
    try:
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
    except Exception as e:
        print(f"Errore nell'inserimento dell'utente: {e}", flush=True)
        raise HTTPException(
            status_code=500,
            detail="Errore nell'inserimento dell'utente"
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
        raise HTTPException(
            status_code=500,
            detail="Errore nell'invio dell'email di verifica"
        )

    return JSONResponse(
        status_code=201,
        content={"message": "Account creato con successo! Verifica la tua email per attivare il tuo account."}
    )

@app.get("/verify-email")
async def verify_email(
    token: str,
    request: Request,
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(
        models.User.email_verification_token == token
    ).first()

    if not user:
        raise HTTPException(
            status_code=400,
            detail="Token di verifica non valido"
        )

    if user.email_verification_expires < datetime.utcnow():
        raise HTTPException(
            status_code=400,
            detail="Token di verifica scaduto. Richiedi un nuovo link."
        )

    user.email_verified = True
    user.active = True
    user.email_verification_token = None
    user.email_verification_expires = None
    
    db.commit()

    return templates.TemplateResponse(
        "success.html",
        {
            "request": request,
            "message": "Email verificata con successo!",
            "type": "Email"
        }
    )


@app.post("/resend-verification/")
async def resend_verification(
    request : Request,
    db: Session = Depends(get_db)
):
    data = await request.json()
    email = data.get("email")
    user = db.query(models.User).filter(
        models.User.email == email
    ).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="Email non trovata"
        )

    if user.email_verified:
        raise HTTPException(
            status_code=400,
            detail="Email già verificata"
        )

    email_verification_token = secrets.token_urlsafe(32)
    token_expires = datetime.utcnow() + timedelta(hours=24)

    user.email_verification_token = email_verification_token
    user.email_verification_expires = token_expires
    db.commit()

    email_sent = send_verification_email(
        email=user.email,
        token=email_verification_token,
        username=user.username
    )

    if not email_sent:
        raise HTTPException(
            status_code=500,
            detail="Errore nell'invio dell'email"
        )

    return {"message": "Email di verifica inviata nuovamente"}

@app.post("/reset-password/")
async def request_reset_password(
    request: Request,
    db: Session = Depends(get_db)
):
    data = await request.json()
    email = data.get("email")

    user = db.query(models.User).filter(
        models.User.email == email
    ).first()

    if not user:
        raise HTTPException(status_code=404, detail="Email non trovata")

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
        raise HTTPException(status_code=500, detail="Errore invio email")

    return {"message": "Email di reset inviata"}

@app.get("/reset-password/")
def get_reset_form(
    token: str,
    request: Request,
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(
        models.User.password_reset_token == token
    ).first()

    if not user or user.password_reset_expires < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Token non valido o scaduto")

    return templates.TemplateResponse(
        "reset_password.html",
        {
            "request": request,
            "token": token
        }
    )

@app.post("/verify-reset-password/")
def verify_reset_password(
    request: Request,
    token: str = Form(...),
    password: str = Form(...),
    confirm_password: str = Form(...),
    db: Session = Depends(get_db)
):
    if password != confirm_password:
        raise HTTPException(status_code=400, detail="Le password non coincidono")

    user = db.query(models.User).filter(
        models.User.password_reset_token == token
    ).first()

    if not user or user.password_reset_expires < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Token non valido o scaduto")

    user.set_password(password)
    user.password_reset_token = None
    user.password_reset_expires = None
    db.commit()

    return templates.TemplateResponse(
        "success.html",
        {
            "request": request,
            "message": "Password modificata con successo!",
            "type": "Password"
        }
    )
