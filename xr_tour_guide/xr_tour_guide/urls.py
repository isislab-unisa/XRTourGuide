from django.contrib import admin
from django.urls import path, include
import nested_admin
from django.contrib.auth import views as auth_views
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    path('admin/', admin.site.urls),
    # path('', include('xr_tour_guide_core.urls')),
    path('nested_admin/', include('nested_admin.urls')),
    path('accounts/', include('allauth.urls')),
    path('', include('xr_tour_guide_public.urls')),
    # path('accounts/', include("django.contrib.auth.urls")),
    # path('accounts/login/', auth_views.LoginView.as_view(), name='login'),
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),   # login
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]