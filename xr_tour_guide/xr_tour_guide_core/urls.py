from django.contrib import admin
from django.urls import path, include
import nested_admin
from views import tour_list

urlpatterns = [
    path('tour_list/<str:category>/', tour_list, name='tour_list'),
]