from django.contrib import admin
from django import forms
from location_field.widgets import LocationWidget
from location_field.models.plain import PlainLocationField
import nested_admin
from unfold.admin import ModelAdmin
from ..models import Tour, Waypoint, WaypointViewImage, WaypointViewLink, TypeOfImage
from django.forms.widgets import ClearableFileInput
from django.utils.safestring import mark_safe
from django.utils.html import format_html
from django.db import models
from django.urls import reverse
from ..forms.waypoint_form import WaypointForm
from .base import UnfoldNestedStackedInline
from django.utils.translation import gettext_lazy as _

class WaypointAdmin(UnfoldNestedStackedInline):
    model = Waypoint
    form = WaypointForm
    extra = 0
    verbose_name = _("Point of Interest")
    verbose_name_plural = _("Tour Points of Interest")
    readonly_fields = ['display_existing_images']
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        
        if not request.user.is_superuser:
            qs = qs.filter(tour__user=request.user)
        
        return qs
    
    fieldsets = (
        (_('📍 Basic Information'), {
            'fields': ('title', 'description'),
            'description': (
                '<div style="background: light-dark(#dbeafe, #1e3a8a); padding: 12px; border-radius: 6px; '
                'margin-bottom: 12px; border-left: 4px solid light-dark(#3b82f6, #60a5fa); '
                'color: light-dark(#1e3a8a, #dbeafe);">'
                '<strong>💡 ' + str(_('Tip:')) + '</strong> ' +
                str(_('Start with a clear title and a brief description. You\'ll add details later.')) +
                '</div>'
            )
        }),
        (_('🗺️ Map Location'), {
            'fields': ('place', 'coordinates',),
            'description': (
                '<div style="background: light-dark(#fef3c7, #78350f); padding: 12px; border-radius: 6px; '
                'margin-bottom: 12px; border-left: 4px solid light-dark(#f59e0b, #fbbf24); '
                'color: light-dark(#78350f, #fef3c7);">'
                '<strong>📌 ' + str(_('How to select:')) + '</strong> ' +
                str(_('Click on the map at the exact point where the location is. You can drag the marker to adjust its position.')) +
                '</div>'
            )
        }),
        (_('🖼️ Images'), {
            'fields': ('uploaded_images', 'display_existing_images'),
            'classes': ('collapse',),
            'description': (
                '<div style="background: light-dark(#d1fae5, #065f46); padding: 12px; border-radius: 6px; '
                'margin-bottom: 12px; border-left: 4px solid light-dark(#10b981, #34d399); '
                'color: light-dark(#065f46, #d1fae5);">'
                '<strong>📷 ' + str(_('Advice:')) + '</strong> ' +
                str(_('Upload 3-5 good quality images showing the location from different angles. Photos help visitors recognize the place!')) +
                '</div>'
            )
        }),
        (_('🎬 Multimedia Content (Optional)'), {
            'fields': ('pdf_item', 'video_item', 'audio_item', 'readme_text', 'additional_images', 'links'),
            'classes': ('collapse',),
            'description': (
                '<div style="background: light-dark(#e0e7ff, #3730a3); padding: 12px; border-radius: 6px; '
                'margin-bottom: 12px; border-left: 4px solid light-dark(#6366f1, #818cf8); '
                'color: light-dark(#3730a3, #e0e7ff);">'
                '<strong>🎥 ' + str(_('Optional but recommended:')) + '</strong> ' +
                str(_('Add extra content to enrich the experience. A PDF with historical info, a video, or an audio guide make the tour more complete.')) +
                '</div>'
            )
        }),
    )
    
    @admin.display(description=_("🖼️ Image Gallery"))
    def display_existing_images(self, obj):
        if not obj or not obj.pk:
            return mark_safe(
                '<div style="background: light-dark(#fef3c7, #78350f); padding: 12px; border-radius: 6px; '
                'border-left: 4px solid light-dark(#f59e0b, #fbbf24); color: light-dark(#78350f, #fef3c7);">'
                '<p style="margin: 0; font-size: 0.875rem;">⚠️ ' + str(_('Save the point of interest first to upload images')) + '</p>'
                '</div>'
            )
        
        images = WaypointViewImage.objects.filter(waypoint=obj, type_of_images=TypeOfImage.DEFAULT)
        
        if not images.exists():
            return mark_safe(
                '<div style="background: light-dark(#f3f4f6, #1f2937); padding: 12px; border-radius: 6px; '
                'color: light-dark(#6b7280, #9ca3af);">'
                '<p style="margin: 0; font-size: 0.875rem;">📷 ' + str(_('No images uploaded yet')) + '</p>'
                '</div>'
            )
        
        html_parts = [
            '<div style="background: light-dark(#ffffff, #1f2937); padding: 16px; border-radius: 8px; '
            'border: 1px solid light-dark(#e5e7eb, #374151);">',
            f'<p style="margin: 0 0 12px 0; font-weight: 600; color: light-dark(#374151, #e5e7eb);">📷 {images.count()} ' + str(_('images uploaded')) + '</p>',
            '<div style="display: flex; flex-wrap: wrap; gap: 16px;">'
        ]
        
        for img in images:
            app_label = WaypointViewImage._meta.app_label
            model_name = WaypointViewImage._meta.model_name
            
            try:
                change_url = reverse(f'admin:{app_label}_{model_name}_change', args=[img.pk])
                delete_link = (
                    f'<a href="{change_url}" '
                    f'style="color: light-dark(#dc2626, #f87171); font-size: 0.75rem; font-weight: 500; text-decoration: none;" '
                    f'target="_blank">🗑️ {_("Manage")}</a>'
                )
            except:
                delete_link = ''
            
            img_url = f"/stream_minio_resource/?tour={img.waypoint.tour.pk}&waypoint={img.waypoint.pk}&file={img.image.name}"
            
            html_parts.append(f'''
                <div style="width: 200px; border: 1px solid light-dark(#e5e7eb, #374151); border-radius: 8px; 
                     overflow: hidden; box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);">
                    <img src="{img_url}" 
                         alt="View image" 
                         onclick="window.open('{img_url}', '_blank')"
                         style="width: 100%; height: 160px; object-fit: cover; cursor: pointer;"
                         title="{_('Click to view image in full screen')}"
                    />
                    <div style="padding: 8px; background: light-dark(#ffffff, #1f2937); display: flex; 
                         justify-content: space-between; align-items: center;">
                        <span style="font-size: 0.75rem; color: light-dark(#6b7280, #9ca3af);">ID: {img.pk}</span>
                        {delete_link}
                    </div>
                </div>
            ''')
        
        html_parts.append('</div></div>')
        
        return mark_safe(''.join(html_parts))
    
    formfield_overrides = {
        PlainLocationField: {"widget": LocationWidget},
    }
    
    class Media:
        js = [
            'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
            'https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.js',
            'admin/js/init_maps.js',
            'admin/js/init_markdown_editor.js',
            'admin/js/hide_waypoint_coordinates.js',
        ]
        css = {
            'all': [
                'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
                'https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.css'
            ]
        }

class WaypointViewImageAdmin(ModelAdmin):

    list_display = ('id', 'waypoint', 'image_preview', 'type_of_images')
    list_filter = ('waypoint__tour',)
    search_fields = ('waypoint__title', 'waypoint__tour__title')
    
    @admin.display(description=_("Preview"))
    def image_preview(self, obj):
        if obj.image:
            return format_html(
                '<img src="{}" style="width: 100px; height: 100px; object-fit: cover; border-radius: 4px;" />',
                obj.image.url
            )
        return _("No image")
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        
        if not request.user.is_superuser:
            qs = qs.filter(waypoint__tour__user=request.user)
        
        return qs
    
    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "waypoint":
            if not request.user.is_superuser:
                kwargs["queryset"] = Waypoint.objects.filter(tour__user=request.user)
        
        return super().formfield_for_foreignkey(db_field, request, **kwargs)

admin.site.register(WaypointViewImage, WaypointViewImageAdmin)

class WaypointViewLinkAdmin(ModelAdmin):
    list_display = ('id', 'waypoint', 'link_preview')
    list_filter = ('waypoint__tour',)
    search_fields = ('waypoint__title', 'waypoint__tour__title', 'link')
    
    fieldsets = (
        (_('🔗 Link Information'), {
            'fields': ('waypoint', 'link'),
            'description': (
                '<div style="background: light-dark(#dbeafe, #1e3a8a); padding: 12px; border-radius: 6px; '
                'margin-bottom: 12px; border-left: 4px solid light-dark(#3b82f6, #60a5fa); '
                'color: light-dark(#1e3a8a, #dbeafe);">'
                '<strong>🔗 ' + str(_('Add Link:')) + '</strong> ' +
                str(_('Insert external URLs to enrich this point of interest (e.g.: official website, Wikipedia, YouTube video)')) +
                '</div>'
            )
        }),
    )
    
    @admin.display(description=_("🔗 Link"))
    def link_preview(self, obj):
        if obj.link:
            return format_html(
                '<a href="{}" target="_blank" style="color: #3b82f6; text-decoration: none;">{}</a>',
                obj.link,
                obj.link[:50] + '...' if len(obj.link) > 50 else obj.link
            )
        return _("No link")
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        
        if not request.user.is_superuser:
            qs = qs.filter(waypoint__tour__user=request.user)
        
        return qs
    
    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "waypoint":
            if not request.user.is_superuser:
                kwargs["queryset"] = Waypoint.objects.filter(tour__user=request.user)
        
        return super().formfield_for_foreignkey(db_field, request, **kwargs)

admin.site.register(WaypointViewLink, WaypointViewLinkAdmin)