from django.shortcuts import render, redirect
from xr_tour_guide_core.models import Tour
import requests
from django.contrib.auth import get_user_model, login as django_login
from django.contrib.auth.models import Group
from django.http import HttpResponse, JsonResponse
from dotenv import load_dotenv
import os
import json
from django.conf import settings
from django.views.decorators.http import require_http_methods

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
            context = {
                "error": "Email required",
                "GOOGLE_CLIENT_ID": os.getenv('GOOGLE_CLIENT_ID', '')
            }
            return render(request, "account/login.html", context)
        
        if not password:
            context = {
                "error": "Password required",
                "GOOGLE_CLIENT_ID": os.getenv('GOOGLE_CLIENT_ID', '')
            }
            return render(request, "account/login.html", context)
        
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
                user.city = user_data.get("city", "") or "Not provided"
                user.description = user_data.get("description", "")  or "Not provided"
            except User.DoesNotExist:
                user = User.objects.create_user(
                    username=user_data["username"],
                    email=email,
                    first_name=user_data.get("name", ""),
                    last_name=user_data.get("surname", ""),
                    city=user_data.get("city", "")  or "Not provided",
                    description=user_data.get("description", "")  or "Not provided"
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
            context = {
                "error": response.json()["detail"],
                "GOOGLE_CLIENT_ID": os.getenv('GOOGLE_CLIENT_ID', '')
            }
            return render(request, "account/login.html", context)

    # GET request - show login form
    context = {
        "GOOGLE_CLIENT_ID": os.getenv('GOOGLE_CLIENT_ID', '')
    }
    return render(request, "account/login.html", context)

@require_http_methods(["POST"])
def google_login(request):
    """Handle Google OAuth login"""
    print("=" * 50)
    print("🔵 GOOGLE LOGIN - Richiesta ricevuta")
    print("=" * 50)
    
    try:
        # Log request info
        print(f"Method: {request.method}")
        print(f"Content-Type: {request.content_type}")
        
        # Parse body
        raw_body = request.body.decode('utf-8')
        print(f"Raw body: {raw_body[:200]}")
        
        data = json.loads(raw_body)
        print(f"Parsed JSON: {data.keys()}")
        
        id_token = data.get('id_token')
        
        if not id_token:
            print("❌ ERROR: ID token mancante")
            return JsonResponse(
                {"detail": "ID token required"},
                status=400
            )
        
        print(f"✅ ID token ricevuto (lunghezza: {len(id_token)})")
        
        # Forward the token to your IDP
        idp_url = f"http://{os.getenv('COMMUNITY_SERVER')}/api/google-login/"
        print(f"🔄 Invio richiesta all'IDP: {idp_url}")
        
        response = requests.post(
            idp_url,
            json={'id_token': id_token},
            timeout=10
        )
        
        print(f"📥 Risposta IDP - Status: {response.status_code}")
        print(f"📥 Risposta IDP - Content: {response.text[:500]}")
        
        if response.status_code == 200:
            data = response.json()
            user_data = data["user"]
            
            print(f"✅ Autenticazione IDP riuscita per: {user_data.get('email')}")
            
            # Get or create the Django user
            try:
                user = User.objects.get(email=user_data["email"])
                print(f"📝 Utente esistente trovato: {user.username}")
                user.username = user_data["username"]
                user.first_name = user_data.get("name", "")
                user.last_name = user_data.get("surname", "")
                user.city = user_data.get("city", "Not provided") or "Not provided"
                user.description = user_data.get("description", "Not provided") or "Not provided"
                user.is_staff = True
            except User.DoesNotExist:
                print(f"🆕 Creazione nuovo utente: {user_data['email']}")
                user = User.objects.create_user(
                    username=user_data["username"],
                    email=user_data["email"],
                    first_name=user_data.get("name", ""),
                    last_name=user_data.get("surname", ""),
                    city=user_data.get("city", "Not provided") or "Not provided",
                    description=user_data.get("description", "Not provided") or "Not provided",
                    is_staff=True
                )
            
            # Add to User group
            group_name = 'User'
            try:
                group = Group.objects.get(name=group_name)
                user.groups.add(group)
            except Group.DoesNotExist:
                print(f"⚠️ Warning: Group '{group_name}' does not exist")
            
            user.save()
            print(f"💾 Utente salvato: {user.username}")
            
            # Log in the user
            user.backend = 'django.contrib.auth.backends.ModelBackend'
            django_login(request, user)
            print(f"🔐 Login Django effettuato")
            
            # Store the access token
            request.session["cs_token"] = data["access"]
            print(f"🎫 Token salvato in sessione")
            
            print("=" * 50)
            print("✅ GOOGLE LOGIN COMPLETATO CON SUCCESSO")
            print("=" * 50)
            
            # IMPORTANTE: Restituisci JSON con l'URL di redirect
            return JsonResponse({
                "success": True,
                "redirect": settings.LOGIN_REDIRECT_URL
            }, status=200)
            
        else:
            error_data = response.json() if response.content else {"detail": "Authentication failed"}
            print(f"❌ Errore dall'IDP: {error_data}")
            return JsonResponse(
                {"detail": error_data.get("detail", "Authentication failed")},
                status=response.status_code
            )
            
    except requests.exceptions.RequestException as e:
        print(f"❌ Errore connessione IDP: {str(e)}")
        return JsonResponse(
            {"detail": "Connection error to authentication server"},
            status=500
        )
    except json.JSONDecodeError as e:
        print(f"❌ Errore parsing JSON: {str(e)}")
        return JsonResponse(
            {"detail": "Invalid JSON in request"},
            status=400
        )
    except Exception as e:
        print(f"❌ Errore generico: {str(e)}")
        import traceback
        traceback.print_exc()
        return JsonResponse(
            {"detail": f"Server error: {str(e)}"},
            status=500
        )
    
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
        return HttpResponse("Email di verifica inviata con successo", status=response.status_code)
    elif response.status_code == 404:
        return HttpResponse("Email non trovata", status=response.status_code)
    elif response.status_code == 400:
        return HttpResponse("Email già verificata", status=response.status_code)
    else:
        return HttpResponse("Errore nell'invio dell'email", status=response.status_code)

def reset_password(request):
    email = request.POST.get('email')
    response = requests.post(
        f"http://{os.getenv('COMMUNITY_SERVER')}/reset-password/",
        json={'email': email}
    )
    if response.status_code == 200:
        return HttpResponse("Email di verifica inviata con successo", status=response.status_code)
    elif response.status_code == 404:
        return HttpResponse("Email non trovata", status=response.status_code)
    elif response.status_code == 400:
        return HttpResponse("Email già verificata", status=response.status_code)
    else:
        return HttpResponse("Errore nell'invio dell'email", status=response.status_code)