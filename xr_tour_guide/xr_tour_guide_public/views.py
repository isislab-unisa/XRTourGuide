from django.shortcuts import render, redirect
from xr_tour_guide_core.models import Tour
import requests
from django.contrib.auth import get_user_model, login as django_login
import secrets
import string
from django.contrib.auth.models import Group

User = get_user_model()

def landing_page(request):
    tours = Tour.objects.filter(parent_tours__isnull=True)[:6]
    return render(request, 'xr_tour_guide_public/landing_page/landing_page.html', context={'tours': tours})

def register_page(request):
    return render(request, "xr_tour_guide_public/register.html")

def login(request):
    if request.method == "POST":
        email = request.POST.get('email')
        password = request.POST.get('password')
        
        response = requests.post(
            'http://172.16.15.162:8002/api/login/',
            data={'email': email, 'password': password}
        )

        if response.status_code == 200:
            data = response.json()
            try:
                user = User.objects.get(email=email)
            except User.DoesNotExist:
                temp_password = ''.join(secrets.choice(
                    string.ascii_letters + string.digits + string.punctuation
                ) for _ in range(42))
                
                user = User.objects.create_user(
                    username=data["user"]["username"],
                    email=email,
                    password=temp_password,
                    first_name=data["user"].get("name", ""),
                    last_name=data["user"].get("surname", ""),
                    city=data["user"].get("city", ""),
                    description=data["user"].get("description", "")
                )
            
            user.is_staff = True
            group_name = 'User'
            group = Group.objects.get(name=group_name)
            user.groups.add(group)
            user.save()

            user.backend = 'django.contrib.auth.backends.ModelBackend'
            django_login(request, user)

            request.session["cs_token"] = data["access_token"]
            return redirect("/admin/")
        else:
            return render(request, "account/login.html", {"error": "Credenziali non valide"})

    return render(request, "account/login.html")

