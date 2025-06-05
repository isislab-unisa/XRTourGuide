from django.contrib import admin
from django.urls import path, include
import nested_admin
from .views import tour_list, tour_details, profile_details, update_profile, delete_account, update_password

urlpatterns = [
    path('tour_list/<str:category>/', tour_list, name='tour_list'),
    path('tour_details/<int:pk>/', tour_details, name='tour_details'),
    path('profile_details/', profile_details, name='profile_details'),
    path('update_profile/', update_profile, name='update_profile'),
    path('delete_account/', delete_account, name='delete_account'),
    path('update_password/', update_password, name='update_password'),
]