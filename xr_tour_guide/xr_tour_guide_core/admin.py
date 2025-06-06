from django.contrib import admin
from django import forms
from location_field.widgets import LocationWidget
from location_field.models.plain import PlainLocationField
import nested_admin
from unfold.admin import ModelAdmin
from unfold.admin import StackedInline as UnfoldStackedInline
from unfold.admin import TabularInline as UnfolTabularInline
from .models import Tour, Waypoint, WaypointView, MediaItem, WaypointViewImage, Tag

class UnfoldNestedStackedInline(nested_admin.NestedStackedInline, UnfoldStackedInline):
    pass

class UnfoldNestedTabularInline(nested_admin.NestedTabularInline, UnfolTabularInline):
    pass

class WaypointViewAdmin(UnfoldNestedTabularInline):
    model = WaypointView
    fields = ['tag', 'default_image']
    extra = 1

class WaypointAdmin(UnfoldNestedTabularInline):
    model = Waypoint
    fields = ['title', 'coordinates', 'description']
    extra = 1
    formfield_overrides = {
        PlainLocationField: {"widget": LocationWidget},
    }
    inlines = [WaypointViewAdmin]


class TourAdmin(nested_admin.NestedModelAdmin, ModelAdmin):
    fields = ('category', 'title', 'subtitle', 'description', 'place', 'coordinates')
    list_display = ('title', 'creation_time', 'category', 'place')
    readonly_fields = ['user', 'creation_time']
    list_filter = ['user', 'category', 'place']
    search_fields = ('title', 'description')
    date_hierarchy = 'creation_time'

    inlines = [WaypointAdmin]

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

class MediaItemAdmin(ModelAdmin):
    pass

class WaypointViewImageAdmin(ModelAdmin):
    pass

class TagAdmin(ModelAdmin):
    pass

admin.site.register(Tag, TagAdmin)
admin.site.register(Tour, TourAdmin)
admin.site.register(MediaItem, MediaItemAdmin)
admin.site.register(WaypointViewImage, WaypointViewImageAdmin)
