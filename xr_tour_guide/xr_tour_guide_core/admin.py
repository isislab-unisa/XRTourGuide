from django.contrib import admin
from .models import Tour, Waypoint, WaypointView, MediaItem, WaypointViewImage, Tag
from unfold.admin import ModelAdmin
from location_field.widgets import LocationWidget
from location_field.models.plain import PlainLocationField

class TourAdmin(ModelAdmin):
    list_display = ('title', 'subtitle', 'description', 'place', 'coordinates')
    readonly_fields = ['user', 'creation_time']
    list_filter = ['user']
    search_fields = ('title', 'description')
    date_hierarchy = 'creation_time'
    
    formfield_overrides = {
        PlainLocationField: {"widget": LocationWidget},
    }

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        return qs.filter(user=request.user)

    def save_model(self, request, obj, form, change):
        if not change:
            obj.user = request.user
        super().save_model(request, obj, form, change)

    def get_changeform_initial_data(self, request):
        initial = super().get_changeform_initial_data(request)
        initial['user'] = request.user.pk
        return initial
    
    def save_related(self, request, form, formsets, change):
        super().save_related(request, form, formsets, change)
        cromo_poi = form.instance
        # generate_data_json(cromo_poi)
    
    def has_change_permission(self, request, obj=None):
        has_permission = super().has_change_permission(request, obj)
        if not has_permission:
            return False
        if obj is None:
            return True
        if obj.status in ['BUILT', 'BUILDING', 'SERVING', 'ENQUEUED']:
            return False
        return True
    
    def has_delete_permission(self, request, obj=None):
        has_permission = super().has_delete_permission(request, obj)
        if not has_permission:
            return False
        if obj is None:
            return True
        if obj.status in ['SERVING', 'BUILDING', 'ENQUEUED']:
            return False
        
        if obj.user != request.user:
            return False
        return True

class WaypointAdmin(ModelAdmin):
    pass

class WaypointViewAdmin(ModelAdmin):
    pass

class MediaItemAdmin(ModelAdmin):
    pass

class WaypointViewImageAdmin(ModelAdmin):
    pass

class TagAdmin(ModelAdmin):
    pass

admin.site.register(Tag, TagAdmin)
admin.site.register(Tour, TourAdmin)
admin.site.register(Waypoint, WaypointAdmin)
admin.site.register(WaypointView, WaypointViewAdmin)
admin.site.register(MediaItem, MediaItemAdmin)
admin.site.register(WaypointViewImage, WaypointViewImageAdmin)