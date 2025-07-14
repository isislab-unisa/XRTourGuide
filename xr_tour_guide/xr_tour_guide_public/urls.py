from django.urls import path
from .views import landing_page
from xr_tour_guide_core.views import RegisterView
from .views import landing_page, register_page

urlpatterns = [
    path('', landing_page, name='landing_page'),
    path("register/", register_page, name="register"),
    path("api/register/", RegisterView.as_view(), name="api_register"),
]