from django.conf import settings

def script_name(request):
    return {
        'FORCE_SCRIPT_NAME': settings.FORCE_SCRIPT_NAME or '',
    }