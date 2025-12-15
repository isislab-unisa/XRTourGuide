from django.shortcuts import render, redirect
from xr_tour_guide_core.models import Tour
import requests
from django.contrib.auth import get_user_model, login as django_login
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
            'http://172.16.15.162:8002/api/token/',
            json={'email': email, 'password': password}
        )

        if response.status_code == 200:
            data = response.json()
            user_data = data["user"]
            
            try:
                user = User.objects.get(email=email)
                user.username = user_data["username"]
                user.first_name = user_data.get("name", "")
                user.last_name = user_data.get("surname", "")
                user.city = user_data.get("city", "")
                user.description = user_data.get("description", "")
            except User.DoesNotExist:
                user = User.objects.create_user(
                    username=user_data["username"],
                    email=email,
                    first_name=user_data.get("name", ""),
                    last_name=user_data.get("surname", ""),
                    city=user_data.get("city", ""),
                    description=user_data.get("description", "")
                )
            
            user.is_staff = True
            group_name = 'User'
            group = Group.objects.get(name=group_name)
            user.groups.add(group)
            user.save()

            user.backend = 'django.contrib.auth.backends.ModelBackend'
            django_login(request, user)

            request.session["cs_token"] = data["access"]
            return redirect("/admin/")
        else:
            return render(request, "account/login.html", {"error": "Credenziali non valide"})

    return render(request, "account/login.html")