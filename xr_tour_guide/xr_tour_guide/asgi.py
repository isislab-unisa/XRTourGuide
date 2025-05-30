import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "xr_tour_guide.settings")

application = get_asgi_application()
