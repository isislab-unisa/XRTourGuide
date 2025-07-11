from django.shortcuts import render
from xr_tour_guide_core.models import Tour

def landing_page(request):
    tours = Tour.objects.filter(parent_tours__isnull=True)[:6]
    return render(request, 'xr_tour_guide_public/landing_page/landing_page.html', context={'tours': tours})