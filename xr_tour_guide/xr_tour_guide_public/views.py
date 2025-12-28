from django.shortcuts import render, redirect
from xr_tour_guide_core.models import Tour
import requests
from django.contrib.auth import get_user_model, login as django_login
from django.contrib.auth.models import Group
from django.http import HttpResponse
from dotenv import load_dotenv
import os
from django.http import JsonResponse
import json, os, requests
from django.conf import settings
load_dotenv()
User = get_user_model()

def landing_page(request):
    tours = Tour.objects.filter(parent_tours__isnull=True)[:6]
    return render(request, 'xr_tour_guide_public/landing_page/landing_page.html', context={'tours': tours})

def register_page(request):
    return render(request, "xr_tour_guide_public/register.html")

def login(request):
    if request.method == "POST":
        email = request.POST.get('email', None)
        password = request.POST.get('password', None)
        
        if not email or "@" not in email:
            return render(request, "account/login.html", {"error": "Email required"})
        
        if not password:
            return render(request, "account/login.html", {"error": "Password required"})
        
        response = requests.post(
            f"http://{os.getenv('COMMUNITY_SERVER')}/api/token/",
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
            return redirect(settings.LOGIN_REDIRECT_URL)
        else:
            return render(request, "account/login.html", {"error": response.json()["detail"]})

    return render(request, "account/login.html")

def register(request):
    if request.method == "POST":
        data = json.loads(request.body)
        username = data.get("username")
        email = data.get("email")
        password = data.get("password")
        name = data.get("firstName")
        surname = data.get("lastName")
        description = data.get("description")
        city = data.get("city")

        try:
            response = requests.post(
                f"http://{os.getenv('COMMUNITY_SERVER')}/api_register/",
                json={
                    "username": username,
                    "email": email,
                    "password": password,
                    "firstName": name,
                    "lastName": surname,
                    "description": description,
                    "city": city
                },
                timeout=10
            )
        except requests.exceptions.RequestException as e:
            return JsonResponse(
                {"detail": "Errore di connessione al server API."},
                status=500
            )

        if response.status_code == 201:
            try:
                data = response.json()
            except ValueError:
                data = {"message": "Registrazione completata con successo"}
            return JsonResponse(data, status=201)

        try:
            error_data = response.json()
        except ValueError:
            error_data = {"detail": response.text}

        return JsonResponse(error_data, status=response.status_code)

    return render(request, "register.html")

def send_verification_email(request):
    email = request.POST.get('email')
    response = requests.post(
        f"http://{os.getenv('COMMUNITY_SERVER')}/resend-verification/",
        json={'email': email}
    )
    if response.status_code == 200:
        return HttpResponse("Email di verifica inviata con successo", status=200)
    else:
        return HttpResponse("Email non valida", status=response.status_code)
