"""
Admin package initialization.
Imports all admin classes to register them with Django admin.
"""

from .base import UnfoldNestedStackedInline, UnfoldNestedTabularInline

from .user_admin import CustomUserAdmin
from .waypoint_admin import WaypointAdmin, WaypointViewImageAdmin
from .tour_admin import TourAdmin

__all__ = [
    'UnfoldNestedStackedInline',
    'UnfoldNestedTabularInline',
    'CustomUserAdmin',
    # 'WaypointAdmin',
    'WaypointViewImageAdmin',
    'TourAdmin',
]

from django.contrib import admin
admin.site.site_header = "🗺️ Tour Management System"
admin.site.site_title = "Tour Admin"
admin.site.index_title = "Benvenuto nel pannello di gestione tour"