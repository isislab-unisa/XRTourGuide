from django.contrib import admin
from django.urls import path, include
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('xr_tour_guide_core.urls')),
    path('nested_admin/', include('nested_admin.urls')),
    path('', include('xr_tour_guide_public.urls')),

]