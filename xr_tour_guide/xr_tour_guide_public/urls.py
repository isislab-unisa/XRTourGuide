from django.urls import path
from .views import landing_page
from .views import landing_page, register_page
from xr_tour_guide_public.views import login, register, send_verification_email

urlpatterns = [
    path('', landing_page, name='landing_page'),
    path("register_platform/", register_page, name="register_platform"),
    path("login/", login, name="login"),
    path("register/", register, name="register"),
    path("send_verification_email/", send_verification_email, name="send_verification_email"),
]