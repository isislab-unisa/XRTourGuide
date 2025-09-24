import sys, os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
import model.models as models
from model.database import SessionLocal, engine

models.Base.metadata.create_all(bind=engine)
app = FastAPI()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

app = FastAPI()

@app.get("/")
async def root():
    return {"message": "Server is running"}

@app.get("/list_services/")
async def list_services(db: Session = Depends(get_db)):
    return db.query(models.Services).all()