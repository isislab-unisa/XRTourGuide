from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from django.contrib.auth import get_user_model
import requests
import os
from dotenv import load_dotenv

load_dotenv()
User = get_user_model()

class JWTFastAPIAuthentication(BaseAuthentication):
    def authenticate(self, request):
        auth_header = request.headers.get('Authorization')
        if not auth_header:
            return None

        if not auth_header.startswith('Bearer '):
            return None

        token = auth_header.split(' ')[1]

        try:
            response = requests.post(
                f"http://{os.getenv("COMMUNITY_SERVER")}/api/verify/",
                data={"token": token}
            )

            if response.status_code != 200:
                raise AuthenticationFailed("Invalid token", status_code=401)

            payload = response.json()
            user_id = payload.get("user_id")
            if not user_id:
                raise AuthenticationFailed("Invalid token payload", status_code=401)

        except Exception:
            raise AuthenticationFailed("Token verify failed", status_code=401)

        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            raise AuthenticationFailed("User not found in Django", status_code=401)

        return (user, None)

