from app.model.database import SessionLocal
from app.model import models
import os
from dotenv import load_dotenv

load_dotenv()

def register_test_app():
    db = SessionLocal()
    
    try:
        test_bundle_id = os.getenv("TEST_BUNDLE_ID")
        
        existing = db.query(models.Services).filter(
            models.Services.domain == test_bundle_id
        ).first()
        
        if existing:
            return
        
        test_app = models.Services(
            name="Local Development App",
            domain=test_bundle_id,
            requester_email=os.getenv("EMAIL_HOST_USER"),
            active=True,
            api_key=None,
            api_secret_hash=None
        )
        
        db.add(test_app)
        db.commit()
        
    finally:
        db.close()

if __name__ == "__main__":
    register_test_app()