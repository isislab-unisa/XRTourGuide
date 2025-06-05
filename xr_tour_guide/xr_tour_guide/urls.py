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
    path('', include('xr_tour_guide_core.urls')),
    path('nested_admin/', include('nested_admin.urls')),
    path('accounts/', include('allauth.urls')),
    path('', include('xr_tour_guide_public.urls')),
    path('api/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]