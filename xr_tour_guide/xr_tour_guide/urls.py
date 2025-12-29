from django.contrib import admin
from django.urls import path, include
from django.conf.urls.i18n import i18n_patterns

urlpatterns = [
    path('i18n/', include('django.conf.urls.i18n')),
    path('', include('xr_tour_guide_core.urls')),
]

urlpatterns += i18n_patterns(
    path('admin/', admin.site.urls),
    path('nested_admin/', include('nested_admin.urls')),
    path('', include('xr_tour_guide_public.urls')),
)
