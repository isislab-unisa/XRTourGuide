from django.shortcuts import render

def landing_page(request):
    return render(request, 'xr_tour_guide_public/landing_page/landing_page.html')