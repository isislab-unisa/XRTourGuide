from django.contrib import admin
from django.urls import path, include, re_path
import nested_admin
from .views import tour_list, tour_details, profile_details, update_profile, delete_account, update_password, stream_minio_resource, \
   get_reviews_by_tour_id, RegisterView, ActivateAccountView, tour_waypoints, tour_detail, create_review, get_reviews_by_user, increment_view_count, \
   PasswordResetView, PasswordResetConfirmView, PasswordResetConfirmSubmit, PasswordResetConfirmPage, build, complete_build, load_model
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
   path('tour_list/', tour_list, name='tour_list'),
   path('tour_details/<int:pk>/', tour_details, name='tour_details'),
   path('profile_details/', profile_details, name='profile_details'),
   path('update_profile/', update_profile, name='update_profile'),
   path('delete_account/', delete_account, name='delete_account'),
   path('update_password/', update_password, name='update_password'),
   path('stream_minio_resource/', stream_minio_resource, name='stream_minio_resource'),
   path('get_reviews_by_tour_id/<int:tour_id>/', get_reviews_by_tour_id, name='get_reviews_by_tour_id'),
   re_path(r'^docs/$', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
   path('register/', RegisterView.as_view(), name='register'),
   path('activate/<uidb64>/<token>/', ActivateAccountView.as_view(), name='activate-account'),
   path('tour_waypoints/<int:tour_id>/', tour_waypoints, name='tour_waypoints'),
   path('tour_detail/<int:tour_id>/', tour_detail, name='tour_detail'),
   path('create_review/', create_review, name='create_review'),
   path('get_reviews_by_user/', get_reviews_by_user, name='get_reviews_by_user'),
   path('increment_view_count/', increment_view_count, name='increment_view_count'),
   path('forgot-password/', PasswordResetView.as_view(), name='forgot-password'),
   path('reset-password-confirm/<uidb64>/<token>/', PasswordResetConfirmPage.as_view(), name='reset-password-confirm-page'),
   path('reset-password-confirm/<uidb64>/<token>/submit/', PasswordResetConfirmSubmit.as_view(), name='reset-password-confirm-submit'),
   path("build/", build, name="build"),
   path("complete_build/", complete_build, name="complete_build"),
   path("load_model/<int:tour_id>/", load_model, name="load_model"),
]