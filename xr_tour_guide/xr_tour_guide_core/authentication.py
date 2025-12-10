from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from django.contrib.auth import get_user_model
import requests

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
                "http://172.16.15.162:8002/api/verify/",
                data={"token": token}
            )
            if response.status_code != 200:
                raise AuthenticationFailed("Invalid token")

            payload = response.json()
            user_id = payload.get("user_id")
            if not user_id:
                raise AuthenticationFailed("Invalid token payload")

        except Exception:
            raise AuthenticationFailed("Token verify failed")

        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            raise AuthenticationFailed("User not found in Django")

        return (user, None)
