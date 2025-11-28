from django.contrib import admin
from ..models import CustomUser
from django.contrib.auth.admin import UserAdmin

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
        """Fixed: removed obj parameter - UserAdmin expects only request"""
        return request.user.is_superuser

    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser