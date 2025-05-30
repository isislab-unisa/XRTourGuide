from django.contrib import admin
from .models import Tour, Waypoint, WaypointView, MediaItem, WaypointViewImage, Tag

class TourAdmin(admin.ModelAdmin):
    pass

class WaypointAdmin(admin.ModelAdmin):
    pass

class WaypointViewAdmin(admin.ModelAdmin):
    pass

class MediaItemAdmin(admin.ModelAdmin):
    pass

class WaypointViewImageAdmin(admin.ModelAdmin):
    pass

class TagAdmin(admin.ModelAdmin):
    pass

admin.site.register(Tag, TagAdmin)
admin.site.register(Tour, TourAdmin)
admin.site.register(Waypoint, WaypointAdmin)
admin.site.register(WaypointView, WaypointViewAdmin)
admin.site.register(MediaItem, MediaItemAdmin)
admin.site.register(WaypointViewImage, WaypointViewImageAdmin)