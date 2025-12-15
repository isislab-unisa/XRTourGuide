from django.contrib import admin
from ..models import CustomUser
from django.contrib.auth.admin import UserAdmin
import requests
from django.contrib import messages

@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    model = CustomUser
    list_filter = ()

    fieldsets = (
        ('Account', {
            'fields': ('username', 'password'),
            'description': 'Credenziali di accesso'
        }),
        ('Informazioni Personali', {
            'fields': ('first_name', 'last_name', 'email', 'city', 'description'),
            'description': 'I tuoi dati personali'
        }),
    )

    def get_list_display(self, request):
        if request.user.is_superuser:
            return ('username', 'email', 'first_name', 'last_name', 'is_staff', 'is_superuser')
        return ('username', 'email', 'first_name', 'last_name')
    
    exclude = ('is_staff', 'is_superuser', 'groups', 'user_permissions', 'last_login', 'date_joined')

    def get_fieldsets(self, request, obj=None):
        if request.user.is_superuser:
            return super().get_fieldsets(request, obj)
        return self.fieldsets

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        return qs.filter(id=request.user.id)

    def has_change_permission(self, request, obj=None):
        if request.user.is_superuser:
            return True
        return obj == request.user

    def has_view_permission(self, request, obj=None):
        if request.user.is_superuser:
            return True
        return obj is None or obj == request.user

    def has_add_permission(self, request):
        return request.user.is_superuser

    def save_model(self, request, obj, form, change):
        if change:
            try:
                payload = {
                    "email": obj.email,
                    "username": obj.username,
                    "firstName": obj.first_name,
                    "lastName": obj.last_name,
                    "city": obj.city,
                    "description": obj.description,
                }

                auth_header = request.headers.get('Authorization')
                if not auth_header:
                    return None

                if not auth_header.startswith('Bearer '):
                    return None

                token = auth_header.split(' ')[1]
                response = requests.post(
                    "http://172.16.15.162:8002/update_profile",
                    json=payload,
                    timeout=5,
                    headers={
                        "Authorization": f"Bearer {token.json()['access']}"
                    }
                )

                if response.status_code != 200:
                    error_message = response.json().get("detail", "Errore di connessione con il Community Server")
                    self.message_user(
                        request,
                        f"Errore nel sincronizzare l'utente con il Community Server: {error_message}",
                        level=messages.ERROR
                    )
                else:
                    self.message_user(
                        request,
                        "Utente sincronizzato correttamente con il Community Server.",
                        level=messages.SUCCESS
                    )
                    super().save_model(request, obj, form, change)

            except Exception as e:
                self.message_user(
                    request,
                    f"Errore di connessione con il Community Server: {e}",
                    level=messages.ERROR
                )
        else:
            super().save_model(request, obj, form, change)
