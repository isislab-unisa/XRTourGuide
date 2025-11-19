from django.contrib import admin
from django import forms
from location_field.widgets import LocationWidget
from location_field.models.plain import PlainLocationField
import nested_admin
from unfold.admin import ModelAdmin
from unfold.admin import StackedInline as UnfoldStackedInline
from unfold.admin import TabularInline as UnfoldTabularInline
from unfold.decorators import display
from .models import Tour, Waypoint, WaypointViewImage, Review
from django.forms.widgets import ClearableFileInput
from django.utils.safestring import mark_safe
from django.utils.html import format_html
from .models import CustomUser
from django.contrib.auth.admin import UserAdmin
from django.core.files.base import ContentFile
from django.db.models import Q
from django.db import models
from django.urls import reverse
from django.middleware.csrf import get_token

@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    model = CustomUser
    fieldsets = UserAdmin.fieldsets + (
        ('Informazioni aggiuntive', {'fields': ('city', 'description')}),
    )
    
class MultipleClearableFileInput(ClearableFileInput):
    def __init__(self, attrs=None):
        super().__init__(attrs)
        if self.attrs is None:
            self.attrs = {}
        self.attrs['multiple'] = True
        
    def render(self, name, value, attrs=None, renderer=None):
        input_html = super().render(name, value, attrs, renderer)
        return mark_safe(f"""
        <div class="flex w-full max-w-2xl items-center justify-between gap-2 rounded-default border border-base-200 px-3 py-2 shadow-xs dark:border-base-700">
            <label class="text-sm font-medium text-base-700 dark:text-base-200">
                {input_html}
            </label>
        </div>
        """)

class WaypointForm(forms.ModelForm):
    uploaded_images = forms.FileField(
        required=False,
        label='Immagini Vista',
        widget=MultipleClearableFileInput(),
        help_text='Carica più immagini contemporaneamente per questo punto di interesse'
    )
    
    readme_text = forms.CharField(
        widget=forms.Textarea(attrs={'class': 'markdown-editor', 'rows': 10}),
        label="Descrizione Dettagliata (Markdown)",
        required=False,
        help_text='Utilizza Markdown per formattare la descrizione completa'
    )
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if 'coordinates' in self.fields:
            old_classes = self.fields['coordinates'].widget.attrs.get('class', '')
            new_classes = f"{old_classes} waypoint-coordinates-field".strip()
            self.fields['coordinates'].widget.attrs['class'] = new_classes
        
        # Add help text to fields
        if 'title' in self.fields:
            self.fields['title'].help_text = 'Nome identificativo del punto di interesse'
        if 'place' in self.fields:
            self.fields['place'].help_text = 'Località o città del punto'
        if 'description' in self.fields:
            self.fields['description'].help_text = 'Breve descrizione visibile agli utenti'

    def clean_uploaded_images(self):
        field_name = self.add_prefix('uploaded_images')
        try:
            return self.files.getlist(field_name)
        except Exception as e:
            return []
            
    def save(self, commit=True):
        instance = super().save(commit=commit)
        
        if commit and hasattr(self, 'cleaned_data'):
            uploaded_files = self.cleaned_data.get('uploaded_images', [])
            for uploaded_file in uploaded_files:
                WaypointViewImage.objects.create(waypoint=instance, image=uploaded_file)
        
        if commit and hasattr(self, 'cleaned_data'):
            readme_text = self.cleaned_data.get('readme_text')
            if readme_text:
                instance.readme_item = ContentFile(readme_text.encode('utf-8'), name='readme.md')
                instance.save()
        
        return instance

    class Meta:
        model = Waypoint
        fields = ['title', 'place', 'coordinates', 'description', 'pdf_item', 'video_item', 'audio_item']
        js = [
            'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
            'https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.js',
            'admin/js/init_markdown_editor.js',
        ]
        css = {
            'all': [
                'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
                'https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.css'
            ]
        }

class UnfoldNestedStackedInline(UnfoldStackedInline, nested_admin.NestedStackedInline):
    pass

class UnfoldNestedTabularInline(UnfoldStackedInline, nested_admin.NestedTabularInline):
    pass

class WaypointAdmin(UnfoldNestedStackedInline):
    model = Waypoint
    form = WaypointForm
    extra = 0  # Changed from 1 to 0 to reduce clutter
    min_num = 1  # Ensure at least one waypoint
    verbose_name = "Punto di Interesse"
    verbose_name_plural = "Punti di Interesse"
    
    # Organize fields into logical fieldsets
    fieldsets = (
        ('Informazioni Base', {
            'fields': ('title', 'place'),
            'description': 'Informazioni principali del punto di interesse'
        }),
        ('Posizione', {
            'fields': ('coordinates',),
            'description': 'Seleziona la posizione sulla mappa'
        }),
        ('Contenuto', {
            'fields': ('description', 'readme_text', 'uploaded_images'),
            'classes': ('collapse',),  # Make it collapsible
            'description': 'Descrizioni e immagini del punto'
        }),
        ('Media Aggiuntivi', {
            'fields': ('pdf_item', 'video_item', 'audio_item'),
            'classes': ('collapse',),  # Make it collapsible
            'description': 'File multimediali opzionali'
        }),
    )
    
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
    
class TourForm(forms.ModelForm):
    class Meta:
        model = Tour
        fields = "__all__"
        widgets = {
            'is_subtour': forms.HiddenInput(),
            'sub_tours': forms.CheckboxSelectMultiple(),
            'description': forms.Textarea(attrs={'rows': 4}),
        }
        labels = {
            'sub_tours': 'Tour Interni',
            'title': 'Titolo del Tour',
            'subtitle': 'Sottotitolo',
            'description': 'Descrizione',
            'place': 'Località',
            'coordinates': 'Coordinate Mappa',
            'default_image': 'Immagine Copertina',
            'category': 'Categoria',
        }
        help_texts = {
            'title': 'Un nome accattivante per il tuo tour',
            'subtitle': 'Breve descrizione che appare sotto il titolo',
            'description': 'Descrizione completa del tour (cosa si vedrà, durata stimata, ecc.)',
            'place': 'Città o area geografica principale del tour',
            'default_image': 'Immagine che rappresenta il tour',
            'sub_tours': 'Seleziona i tour interni da includere in questo tour',
            'category': 'Tipologia del tour',
        }

    def __init__(self, *args, **kwargs):
        request = kwargs.pop("request", None)
        super().__init__(*args, **kwargs)
        self.fields['sub_tours'].widget.attrs.update({
            'class': 'unfold-multiselect flex flex-col gap-2 p-2 border rounded-lg bg-white shadow-sm'
        })

        if request and "_popup" in request.GET:
            self.fields['category'].initial = 'INSIDE'
            self.fields['category'].disabled = True
            self.fields['category'].widget = forms.HiddenInput()
            self.fields['is_subtour'].initial = True

class TourAdmin(nested_admin.NestedModelAdmin, ModelAdmin):
    show_facets = admin.ShowFacets.ALLOW
    hide_ordering_field = True
    compressed_fields = True
    
    # Organize fields into logical fieldsets for better UX
    fieldsets = (
        ('Informazioni Principali', {
            'fields': ('category', 'title', 'subtitle'),
            'description': 'Le informazioni base del tuo tour'
        }),
        ('Descrizione e Posizione', {
            'fields': ('description', 'place', 'coordinates'),
        }),
        ('Immagine', {
            'fields': ('default_image',),
            'description': 'Carica un\'immagine rappresentativa del tour'
        }),
        ('Tour Interni', {
            'fields': ('sub_tours',),
            'classes': ('collapse',),
            'description': 'Aggiungi tour già esistenti come sotto-sezioni'
        }),
        ('Informazioni Sistema', {
            'fields': ('user', 'creation_time', 'status', 'is_subtour'),
            'classes': ('collapse',),
        }),
    )
    
    list_display = ('title', 'category_badge', 'place', 'user', 'status_badge', 'waypoint_count', 'creation_time')
    readonly_fields = ['user', 'creation_time', 'status']
    list_filter = ['category', 'status', 'place', 'creation_time', 'user']
    search_fields = ('title', 'subtitle', 'description', 'place')
    date_hierarchy = 'creation_time'
    form = TourForm
    list_per_page = 20
    
    # Add filter on the right side
    list_filter_submit = True  # Add submit button to filters
    
    formfield_overrides = {
        models.ManyToManyField: {'widget': forms.CheckboxSelectMultiple},
    }
    
    inlines = [WaypointAdmin]

    class Media:
        js = ['https://code.jquery.com/jquery-3.6.0.min.js', 
              'admin/js/init_maps.js',
              'admin/js/init_markdown_editor.js',
              'admin/js/hide_waypoint_coordinates.js',
              'admin/js/refresh_subtours_checkboxes.js',
              'admin/js/loader.js'
            ]
    
    # Custom display methods for better visualization
    @display(description="Categoria", ordering="category")
    def category_badge(self, obj):
        colors = {
            'INSIDE': 'bg-blue-100 text-blue-800',
            'OUTSIDE': 'bg-green-100 text-green-800',
            'MIXED': 'bg-purple-100 text-purple-800',
        }
        color_class = colors.get(obj.category, 'bg-gray-100 text-gray-800')
        return format_html(
            '<span class="px-2 py-1 rounded text-xs font-semibold {}">{}</span>',
            color_class,
            obj.get_category_display()
        )
    
    @display(description="Stato", ordering="status")
    def status_badge(self, obj):
        colors = {
            'READY': 'bg-green-100 text-green-800',
            'BUILDING': 'bg-yellow-100 text-yellow-800',
            'SERVING': 'bg-blue-100 text-blue-800',
            'ENQUEUED': 'bg-orange-100 text-orange-800',
            'FAILED': 'bg-red-100 text-red-800',
        }
        color_class = colors.get(obj.status, 'bg-gray-100 text-gray-800')
        return format_html(
            '<span class="px-2 py-1 rounded text-xs font-semibold {}">{}</span>',
            color_class,
            obj.get_status_display() if hasattr(obj, 'get_status_display') else obj.status
        )
    
    @display(description="Punti di Interesse")
    def waypoint_count(self, obj):
        count = obj.waypoints.count()
        return format_html(
            '<span class="font-semibold">{} punti</span>',
            count
        )
        
    def get_form(self, request, obj=None, **kwargs):
        Form = super().get_form(request, obj, **kwargs)

        def form_wrapper(*args, **kw):
            kw["request"] = request
            return Form(*args, **kw)

        return form_wrapper

    def formfield_for_manytomany(self, db_field, request, **kwargs):
        if db_field.name == "sub_tours":
            tour_id = request.resolver_match.kwargs.get("object_id")
            available = Tour.objects.filter(
                    is_subtour=True, 
                    category="INSIDE", 
                    parent_tours__isnull=True
                )
            if tour_id:
                tour = Tour.objects.get(id=tour_id)
                associated = tour.sub_tours.all()
                kwargs["queryset"] = (associated | available).distinct()
            else:
                kwargs["queryset"] = available
            
            return super().formfield_for_manytomany(db_field, request, **kwargs)

        return super().formfield_for_manytomany(db_field, request, **kwargs)

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        qs = qs.filter(is_subtour=False)
        if not request.user.is_superuser:
            qs = qs.filter(user=request.user)
        return qs

    def save_model(self, request, obj, form, change):
        if not change:
            obj.user = request.user
        if change:
            obj.status = "READY"
        super().save_model(request, obj, form, change)

    def get_changeform_initial_data(self, request):
        initial = super().get_changeform_initial_data(request)
        initial['user'] = request.user.pk
        return initial

    def save_related(self, request, form, formsets, change):
        super().save_related(request, form, formsets, change)
        for subtour in form.instance.sub_tours.all():
            if not subtour.is_subtour:
                subtour.is_subtour = True
                subtour.save()
            if form.instance not in subtour.parent_tours.all():
                subtour.parent_tours.add(form.instance)

    def has_change_permission(self, request, obj=None):
        has_permission = super().has_change_permission(request, obj)
        if not has_permission:
            return False
        if obj is None:
            return True
        if obj.status in ['BUILDING', 'SERVING', 'ENQUEUED']:
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
    list_display = ['id', 'created_at']
    list_filter = ['created_at']
    search_fields = ['id']

class WaypointViewImageAdmin(ModelAdmin):
    list_display = ['id', 'waypoint', 'image']
    list_filter = ['waypoint']
    search_fields = ['waypoint__title']

class ReviewAdmin(ModelAdmin):
    list_display = ['tour', 'user', 'rating']
    list_filter = ['rating']
    search_fields = ['tour__title', 'user__username', 'comment']

admin.site.register(Review, ReviewAdmin)
admin.site.register(Tour, TourAdmin)
admin.site.register(WaypointViewImage, WaypointViewImageAdmin)
# admin.site.register(WaypointLink, WaypointLinkInline)