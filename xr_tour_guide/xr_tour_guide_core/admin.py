
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
    # exclude = ("is_active", "is_staff", "is_superuser")
    fieldsets = UserAdmin.fieldsets + (
        ('Informazioni aggiuntive', {'fields': ('city', 'description')}),
    )

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if request.user.is_superuser:
            return qs
        return qs.filter(id=request.user.id)

    def has_change_permission(self, request, obj=None):
        if request.user.is_superuser:
            return True
        if obj is not None and obj == request.user:
            return True
        return False

    def has_view_permission(self, request, obj=None):
        if request.user.is_superuser:
            return True
        if obj is None or obj == request.user:
            return True
        return False

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
        label='Carica Nuove Immagini',
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
    min_num = 0  # Ensure at least one waypoint
    verbose_name = "Punto di Interesse"
    verbose_name_plural = "Punti di Interesse"
    readonly_fields = ['display_existing_images']
    
    # Organize fields into logical fieldsets
    fieldsets = (
        ('Informazioni Base', {
            'fields': ('title', 'description'),
            'description': 'Informazioni principali del punto di interesse'
        }),
        ('Posizione', {
            'fields': ('place', 'coordinates'),
            'description': 'Seleziona la posizione sulla mappa'
        }),
        ('Contenuto', {
            'fields': ('uploaded_images', 'display_existing_images'),
            'classes': ('collapse',),
            'description': 'Descrizioni e immagini del punto'
        }),
        ('Media Aggiuntivi', {
            'fields': ('pdf_item', 'video_item', 'audio_item', 'readme_text'),
            'classes': ('collapse',),
            'description': 'File multimediali opzionali'
        }),
    )
    
    @admin.display(description="Immagini Caricate")
    def display_existing_images(self, obj):
        if not obj or not obj.pk:
            return mark_safe('<p class="text-sm text-gray-500">Salva prima il waypoint per visualizzare le immagini</p>')
        
        images = WaypointViewImage.objects.filter(waypoint=obj)
        
        if not images.exists():
            return mark_safe('<p class="text-sm text-gray-500">Nessuna immagine caricata</p>')
        
        html_parts = ['<div class="flex flex-wrap gap-4">']
        
        for img in images:
            # Get the app label dynamically
            app_label = WaypointViewImage._meta.app_label
            model_name = WaypointViewImage._meta.model_name
            
            try:
                # Try to get the change URL (which typically has a delete button)
                change_url = reverse(f'admin:{app_label}_{model_name}_change', args=[img.pk])
                delete_link = f'<a href="{change_url}" class="text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300 text-xs font-medium" target="_blank">Gestisci</a>'
            except:
                # If that fails, just don't show the delete link
                delete_link = ''
            
            img_url = img.image.url if img.image else ''
            
            html_parts.append(f'''
                <div class="relative group border rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow" style="width: 200px;">
                    <img src="{img_url}" 
                         alt="View image" 
                         class="w-full h-40 object-cover cursor-pointer"
                         onclick="window.open('{img_url}', '_blank')"
                         style="cursor: pointer;"
                    />
                    <div class="p-2 bg-white dark:bg-gray-800 flex justify-between items-center">
                        <span class="text-xs text-gray-500 dark:text-gray-400 truncate">ID: {img.pk}</span>
                        {delete_link}
                    </div>
                </div>
            ''')
        
        html_parts.append('</div>')
        html_parts.append(f'<p class="mt-3 text-sm text-gray-600 dark:text-gray-400">Totale: {images.count()} immagini</p>')
        
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
    
class TourForm(forms.ModelForm):
    class Meta:
        model = Tour
        fields = "__all__"
        widgets = {
            'is_subtour': forms.HiddenInput(),
            'sub_tours': forms.CheckboxSelectMultiple(),
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
    # fields = ('category', 'title', 'subtitle', 'description', 'place', 'coordinates', 'default_image', 'sub_tours', 'is_subtour')
    list_display = ('title', 'creation_time', 'category', 'place', 'user', 'status')
    readonly_fields = ['user', 'creation_time']
    list_filter = ['user', 'category', 'place']
    search_fields = ('title', 'description')
    date_hierarchy = 'creation_time'
    form = TourForm

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

    formfield_overrides = {
        models.ManyToManyField: {'widget': forms.CheckboxSelectMultiple},
    }
    widgets = {
            'is_subtour': forms.HiddenInput()
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
    pass

class WaypointViewImageAdmin(ModelAdmin):
    pass

class ReviewAdmin(ModelAdmin):
    pass

admin.site.register(Review, ReviewAdmin)
admin.site.register(Tour, TourAdmin)
admin.site.register(WaypointViewImage, WaypointViewImageAdmin)
# admin.site.register(WaypointLink, WaypointLinkInline)