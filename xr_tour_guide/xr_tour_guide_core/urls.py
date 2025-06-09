from django.contrib import admin
from django.urls import path, include, re_path
import nested_admin
from .views import tour_list, tour_details, profile_details, update_profile, delete_account, update_password, stream_minio_resource, get_reviews
from drf_yasg.views import get_schema_view
from drf_yasg import openapi
from rest_framework import permissions

schema_view = get_schema_view(
   openapi.Info(
      title="Cromo API",
      default_version='v1',
      description="These are the API endpoints for Cromo.",
      terms_of_service="https://www.google.com/policies/terms/",
      contact=openapi.Contact(email="contact@dummy.local"),
      license=openapi.License(name="BSD License"),
   ),
   public=True,
   permission_classes=(permissions.AllowAny,),
)

urlpatterns = [
    path('tour_list/<str:category>/', tour_list, name='tour_list'),
    path('tour_details/<int:pk>/', tour_details, name='tour_details'),
    path('profile_details/', profile_details, name='profile_details'),
    path('update_profile/', update_profile, name='update_profile'),
    path('delete_account/', delete_account, name='delete_account'),
    path('update_password/', update_password, name='update_password'),
    path('stream_minio_resource/<int:waypoint_id>/', stream_minio_resource, name='stream_minio_resource'),
    path('get_reviews/<int:tour_id>/', get_reviews, name='get_reviews'),
    re_path(r'^docs/$', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
]