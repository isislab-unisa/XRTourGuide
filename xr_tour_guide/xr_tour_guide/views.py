from django.contrib import admin
from django.urls import path
from django.views.generic import TemplateView
from unfold.views import UnfoldModelAdminViewMixin
from xr_tour_guide_core.models import Tour, Review
from django.db.models import Avg, Count


admin.site.index_title = 'Dashboard'

class DashboardView(UnfoldModelAdminViewMixin, TemplateView):
    title = "Dashboard"
    permission_required = ()
    template_name = "admin/index.html"
    
def dashboard_callback(request, context):
    user_tours = Tour.objects.filter(parent_tours__isnull=True, is_subtour=False, user=request.user)
    reviews = Review.objects.filter(user=request.user)

    tour_stats = user_tours.annotate(
        review_count=Count('reviews'),
        avg_rating=Avg('reviews__rating'),
        subtour_count=Count('sub_tours')
    )

    context.update({
        "tours": user_tours,
        "reviews": reviews,
        "tour_stats": tour_stats,
    })
    return context
