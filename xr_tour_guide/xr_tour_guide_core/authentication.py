from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
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
                f"http://{os.getenv('COMMUNITY_SERVER')}/api/verify/",
                data={"token": token}
            )

            if response.status_code != 200:
                raise AuthenticationFailed("Invalid token")

            payload = response.json()
            print(f"Payload: {payload}")
            username = payload.get("username")
            if not username:
                raise AuthenticationFailed("Invalid token payload")

        except requests.RequestException as e:
            raise AuthenticationFailed("Token verify failed")

        try:
            user = User.objects.get(username=username)
            user.email = payload.get("email", user.email)
            user.first_name = payload.get("name", user.first_name)
            user.last_name = payload.get("surname", user.last_name)
            user.city = payload.get("city", user.city) or "Not provided"
            user.description = payload.get("description", user.description) or "Not provided"
            user.save()
        except User.DoesNotExist:
            user = User.objects.create_user(
                username=username,
                email=payload.get("email", ""),
                first_name=payload.get("name", ""),
                last_name=payload.get("surname", ""),
                city=payload.get("city", "") or "Not provided",
                description=payload.get("description", "") or "Not provided"
            )
            user.set_unusable_password()
            user.is_staff = True
            group_name = 'User'
            try:
                group = Group.objects.get(name=group_name)
                user.groups.add(group)
            except Group.DoesNotExist:
                pass
            user.save()

        if hasattr(request, 'session'):
            request.session["cs_token"] = token

        return (user, None)
