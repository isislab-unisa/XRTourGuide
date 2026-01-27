from django.urls import path
from .views import landing_page
from .views import landing_page, register_page
from xr_tour_guide_public.views import login, register, send_verification_email, reset_password, google_login

urlpatterns = [
    path('', landing_page, name='landing_page'),
    path("register_platform/", register_page, name="register_platform"),
    path("login/", login, name="login"),
    path("register/", register, name="register"),
    path("send_verification_email/", send_verification_email, name="send_verification_email"),
    path("reset_password/", reset_password, name="reset_password"),
    path('google-login/', google_login, name='google_login'),
]