from django.contrib import admin
from django.urls import path, include
import nested_admin
from django.contrib.auth import views as auth_views

urlpatterns = [
    path('admin/', admin.site.urls),
    # path('', include('xr_tour_guide_core.urls')),
    path('nested_admin/', include('nested_admin.urls')),
    path('accounts/', include('allauth.urls')),
    path('', include('xr_tour_guide_public.urls')),
    # path('accounts/', include("django.contrib.auth.urls")),
    # path('accounts/login/', auth_views.LoginView.as_view(), name='login'),
]