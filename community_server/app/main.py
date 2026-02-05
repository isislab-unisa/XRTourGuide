import sys, os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from app.model import models
from app.model.database import SessionLocal, engine
import dotenv
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.sessions import SessionMiddleware

from app.routes import auth, services, users, profile

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
app.add_middleware(SessionMiddleware, secret_key=os.getenv("JWT_SECRET"))

app.include_router(auth.router, tags=["Authentication"])
app.include_router(services.router, tags=["Services"])
app.include_router(users.router, tags=["Users"])
app.include_router(profile.router, tags=["Profile"])