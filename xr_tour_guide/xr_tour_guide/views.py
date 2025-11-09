from django.contrib import admin
from django.urls import path
from django.views.generic import TemplateView
from unfold.views import UnfoldModelAdminViewMixin
from xr_tour_guide_core.models import Tour


admin.site.index_title = 'Dashboard'

class DashboardView(UnfoldModelAdminViewMixin, TemplateView):
    title = "Dashboard"
    permission_required = ()
    template_name = "admin/index.html"
    
def dashboard_callback(request, context):
    context.update({
        "tours": Tour.objects.filter(parent_tours__isnull=True, is_subtour=False, user=request.user),
    })
    return context
