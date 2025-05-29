from django.contrib import admin
from .models import Tour, Waypoint, WaypointView, MediaItem, WaypointViewImage


admin.site.register(Tour)
admin.site.register(Waypoint)
admin.site.register(WaypointView)
admin.site.register(MediaItem)
admin.site.register(WaypointViewImage)