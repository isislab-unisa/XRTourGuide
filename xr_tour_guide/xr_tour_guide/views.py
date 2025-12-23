from django.contrib import admin
from django.urls import path
from django.views.generic import TemplateView
from unfold.views import UnfoldModelAdminViewMixin
from xr_tour_guide_core.models import Tour, Review, Waypoint
from django.db.models import Avg, Count
from django.core.paginator import Paginator
import json


admin.site.index_title = 'Dashboard'


class DashboardView(UnfoldModelAdminViewMixin, TemplateView):
    title = "Dashboard"
    permission_required = ()
    template_name = "admin/index.html"


def dashboard_callback(request, context):
    user_tours = (
        Tour.objects
            .filter(parent_tours__isnull=True, is_subtour=False, user=request.user)
            .annotate(
                review_count=Count('reviews'),
                avg_rating=Avg('reviews__rating'),
                subtour_count=Count('sub_tours'),
                waypoint_count=Count('waypoints')
            )
            .order_by('-creation_time')
    )

    total_tours = user_tours.count()
    total_reviews = Review.objects.filter(tour__user=request.user).count()
    total_waypoints = Waypoint.objects.filter(tour__user=request.user).count()
    
    avg_rating_result = Review.objects.filter(tour__user=request.user).aggregate(
        avg=Avg('rating')
    )
    avg_rating = avg_rating_result['avg']

    category_distribution = (
        user_tours
            .values('category')
            .annotate(count=Count('id'))
            .order_by('category')
    )
    
    category_data = {
        'labels': [item['category'] for item in category_distribution],
        'values': [item['count'] for item in category_distribution]
    }

    status_distribution = (
        user_tours
            .values('status')
            .annotate(count=Count('id'))
            .order_by('status')
    )
    
    status_data = {
        'labels': [item['status'] for item in status_distribution],
        'values': [item['count'] for item in status_distribution]
    }

    paginator = Paginator(user_tours, 6)
    page_number = request.GET.get("page")
    page_obj = paginator.get_page(page_number)

    context.update({
        "tours": page_obj,
        "total_tours": total_tours,
        "total_reviews": total_reviews,
        "total_waypoints": total_waypoints,
        "avg_rating": avg_rating,
        "category_data": json.dumps(category_data),
        "status_data": json.dumps(status_data),
    })
    
    return context