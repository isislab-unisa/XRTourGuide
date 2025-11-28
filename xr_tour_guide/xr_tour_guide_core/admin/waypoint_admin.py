from django.contrib import admin
from django import forms
from location_field.widgets import LocationWidget
from location_field.models.plain import PlainLocationField
import nested_admin
from unfold.admin import ModelAdmin
from ..models import Tour, Waypoint, WaypointViewImage
from django.forms.widgets import ClearableFileInput
from django.utils.safestring import mark_safe
from django.utils.html import format_html
from django.db import models
from django.urls import reverse
from ..forms.waypoint_form import WaypointForm
from .base import UnfoldNestedStackedInline  # ← Import from base.py instead

class WaypointAdmin(UnfoldNestedStackedInline):
    model = Waypoint
    form = WaypointForm
    extra = 0
    verbose_name = "Punto di Interesse"
    verbose_name_plural = "Punti di Interesse del Tour"
    readonly_fields = ['display_existing_images']
    
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        
        if not request.user.is_superuser:
            qs = qs.filter(tour__user=request.user)
        
        return qs
    
    fieldsets = (
        ('📍 Informazioni Base', {
            'fields': ('title', 'description'),
            'description': (
                '<div style="background: light-dark(#dbeafe, #1e3a8a); padding: 12px; border-radius: 6px; '
                'margin-bottom: 12px; border-left: 4px solid light-dark(#3b82f6, #60a5fa); '
                'color: light-dark(#1e3a8a, #dbeafe);">'
                '<strong>💡 Suggerimento:</strong> '
                'Inizia con un titolo chiaro e una descrizione breve. Aggiungerai i dettagli dopo.'
                '</div>'
            )
        }),
        ('🗺️ Posizione sulla Mappa', {
            'fields': ('place', 'coordinates',),
            'description': (
                '<div style="background: light-dark(#fef3c7, #78350f); padding: 12px; border-radius: 6px; '
                'margin-bottom: 12px; border-left: 4px solid light-dark(#f59e0b, #fbbf24); '
                'color: light-dark(#78350f, #fef3c7);">'
                '<strong>📌 Come selezionare:</strong> '
                'Clicca sulla mappa nel punto esatto dove si trova il luogo. '
                'Puoi trascinare il marker per regolarne la posizione.'
                '</div>'
            )
        }),
        ('🖼️ Immagini', {
            'fields': ('uploaded_images', 'display_existing_images'),
            'classes': ('collapse',),
            'description': (
                '<div style="background: light-dark(#d1fae5, #065f46); padding: 12px; border-radius: 6px; '
                'margin-bottom: 12px; border-left: 4px solid light-dark(#10b981, #34d399); '
                'color: light-dark(#065f46, #d1fae5);">'
                '<strong>📷 Consiglio:</strong> '
                'Carica 3-5 immagini di buona qualità che mostrino il luogo '
                'da diverse angolazioni. Le foto aiutano i visitatori a riconoscere il posto!'
                '</div>'
            )
        }),
        ('🎬 Contenuti Multimediali (Opzionale)', {
            'fields': ('pdf_item', 'video_item', 'audio_item', 'readme_text'),
            'classes': ('collapse',),
            'description': (
                '<div style="background: light-dark(#e0e7ff, #3730a3); padding: 12px; border-radius: 6px; '
                'margin-bottom: 12px; border-left: 4px solid light-dark(#6366f1, #818cf8); '
                'color: light-dark(#3730a3, #e0e7ff);">'
                '<strong>🎥 Opzionale ma consigliato:</strong> '
                'Aggiungi contenuti extra per arricchire l\'esperienza. '
                'Un PDF con info storiche, un video o una guida audio rendono il tour più completo.'
                '</div>'
            )
        }),
    )
    
    @admin.display(description="🖼️ Galleria Immagini")
    def display_existing_images(self, obj):
        if not obj or not obj.pk:
            return mark_safe(
                '<div style="background: light-dark(#fef3c7, #78350f); padding: 12px; border-radius: 6px; '
                'border-left: 4px solid light-dark(#f59e0b, #fbbf24); color: light-dark(#78350f, #fef3c7);">'
                '<p style="margin: 0; font-size: 0.875rem;">⚠️ Salva prima il punto di interesse per poter caricare le immagini</p>'
                '</div>'
            )
        
        images = WaypointViewImage.objects.filter(waypoint=obj)
        
        if not images.exists():
            return mark_safe(
                '<div style="background: light-dark(#f3f4f6, #1f2937); padding: 12px; border-radius: 6px; '
                'color: light-dark(#6b7280, #9ca3af);">'
                '<p style="margin: 0; font-size: 0.875rem;">📷 Nessuna immagine caricata ancora</p>'
                '</div>'
            )
        
        html_parts = [
            '<div style="background: light-dark(#ffffff, #1f2937); padding: 16px; border-radius: 8px; '
            'border: 1px solid light-dark(#e5e7eb, #374151);">',
            f'<p style="margin: 0 0 12px 0; font-weight: 600; color: light-dark(#374151, #e5e7eb);">📷 {images.count()} immagini caricate</p>',
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
                    f'target="_blank">🗑️ Gestisci</a>'
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
                         title="Clicca per vedere l'immagine a schermo intero"
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

    list_display = ('id', 'waypoint', 'image_preview')
    list_filter = ('waypoint__tour',)
    search_fields = ('waypoint__title', 'waypoint__tour__title')
    
    @admin.display(description="Anteprima")
    def image_preview(self, obj):
        if obj.image:
            return format_html(
                '<img src="{}" style="width: 100px; height: 100px; object-fit: cover; border-radius: 4px;" />',
                obj.image.url
            )
        return "Nessuna immagine"
    
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