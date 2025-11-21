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

# ============================================================================
# CUSTOM USER ADMIN
# ============================================================================

@admin.register(CustomUser)
class CustomUserAdmin(ModelAdmin, UserAdmin):
    """
    Gestione profilo utente - puoi modificare solo il tuo profilo
    """
    model = CustomUser

    fieldsets = (
        ('Account', {
            'fields': ('username', 'password'),
            'description': 'Credenziali di accesso'
        }),
        ('Informazioni Personali', {
            'fields': ('first_name', 'last_name', 'email', 'city', 'description'),
            'description': 'I tuoi dati personali'
        }),
    )

    exclude = ('is_staff', 'is_superuser', 'groups', 'user_permissions', 'last_login', 'date_joined')

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

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


# ============================================================================
# CUSTOM WIDGETS
# ============================================================================

class MultipleClearableFileInput(ClearableFileInput):
    """Widget personalizzato per upload multiplo di immagini"""
    
    def __init__(self, attrs=None):
        super().__init__(attrs)
        if self.attrs is None:
            self.attrs = {}
        self.attrs['multiple'] = True
        self.attrs['accept'] = 'image/*'
        
    def render(self, name, value, attrs=None, renderer=None):
        input_html = super().render(name, value, attrs, renderer)
        return mark_safe(f"""
        <div class="image-upload-container">
            <div class="flex w-full max-w-2xl items-center justify-between gap-2 rounded-default border border-base-200 px-3 py-2 shadow-xs dark:border-base-700">
                <label class="text-sm font-medium text-base-700 dark:text-base-200">
                    {input_html}
                </label>
            </div>
            <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">
                💡 Puoi selezionare più immagini contemporaneamente (formati: JPG, PNG, WebP)
            </p>
        </div>
        """)


# ============================================================================
# FORMS
# ============================================================================

class WaypointForm(forms.ModelForm):
    """Form per la creazione/modifica di un Punto di Interesse"""
    
    uploaded_images = forms.FileField(
        required=False,
        label='📷 Aggiungi Immagini',
        widget=MultipleClearableFileInput(),
        help_text='Carica le foto che meglio rappresentano questo luogo'
    )
    
    readme_text = forms.CharField(
        widget=forms.Textarea(attrs={
            'class': 'markdown-editor', 
            'rows': 10,
            'placeholder': 'Scrivi qui la descrizione dettagliata usando Markdown...\n\n'
                          '**Esempio:**\n'
                          '# Titolo\n'
                          '## Sottotitolo\n'
                          '- Elenco puntato\n'
                          '- Altro punto\n\n'
                          'Testo normale con **grassetto** e *corsivo*'
        }),
        label="📝 Descrizione Dettagliata (Markdown)",
        required=False,
        help_text='Utilizza Markdown per formattare la descrizione completa. Puoi includere titoli, elenchi, grassetto, corsivo, ecc.'
    )
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        # Add custom CSS class for coordinates field
        if 'coordinates' in self.fields:
            old_classes = self.fields['coordinates'].widget.attrs.get('class', '')
            new_classes = f"{old_classes} waypoint-coordinates-field".strip()
            self.fields['coordinates'].widget.attrs['class'] = new_classes
        
        # Enhanced help texts with emojis for better visual recognition
        field_configs = {
            'title': {
                'help_text': '🏛️ Il nome di questo punto di interesse (es: "Duomo di Milano", "Castello Sforzesco")',
                'widget_attrs': {'placeholder': 'Es: Duomo di Milano'}
            },
            'place': {
                'help_text': '📍 Città o località (es: "Milano", "Firenze")',
                'widget_attrs': {'placeholder': 'Es: Milano'}
            },
            'description': {
                'help_text': '✍️ Una breve descrizione che apparirà nella lista dei punti (max 2-3 righe)',
                'widget_attrs': {
                    'placeholder': 'Es: Capolavoro dell\'architettura gotica, simbolo della città...',
                    'rows': 3
                }
            },
            'coordinates': {
                'help_text': '🗺️ Clicca sulla mappa per selezionare la posizione esatta del punto'
            },
            'pdf_item': {
                'help_text': '📄 Carica un PDF con informazioni aggiuntive (opzionale)'
            },
            'video_item': {
                'help_text': '🎥 Carica un video descrittivo (opzionale)'
            },
            'audio_item': {
                'help_text': '🎵 Carica una guida audio (opzionale)'
            }
        }
        
        for field_name, config in field_configs.items():
            if field_name in self.fields:
                self.fields[field_name].help_text = config['help_text']
                if 'widget_attrs' in config:
                    self.fields[field_name].widget.attrs.update(config['widget_attrs'])

    def clean_uploaded_images(self):
        field_name = self.add_prefix('uploaded_images')
        try:
            return self.files.getlist(field_name)
        except Exception:
            return []
            
    def save(self, commit=True):
        instance = super().save(commit=commit)
        
        # Handle multiple image uploads
        if commit and hasattr(self, 'cleaned_data'):
            uploaded_files = self.cleaned_data.get('uploaded_images', [])
            for uploaded_file in uploaded_files:
                WaypointViewImage.objects.create(waypoint=instance, image=uploaded_file)
        
        # Handle readme markdown file
        if commit and hasattr(self, 'cleaned_data'):
            readme_text = self.cleaned_data.get('readme_text')
            if readme_text:
                instance.readme_item = ContentFile(readme_text.encode('utf-8'), name='readme.md')
                instance.save()
        
        return instance

    class Meta:
        model = Waypoint
        fields = ['title', 'place', 'coordinates', 'description', 'pdf_item', 'video_item', 'audio_item']


class TourForm(forms.ModelForm):
    """Form per la creazione/modifica di un Tour"""
    
    class Meta:
        model = Tour
        fields = "__all__"
        widgets = {
            'is_subtour': forms.HiddenInput(),
            'sub_tours': forms.CheckboxSelectMultiple(),
            'description': forms.Textarea(attrs={'rows': 4}),
        }
        labels = {
            'sub_tours': '🔗 Tour Interni',
            'title': '🎯 Titolo del Tour',
            'subtitle': '📌 Sottotitolo',
            'description': '📝 Descrizione',
            'place': '📍 Località',
            'coordinates': '🗺️ Coordinate Mappa',
            'default_image': '🖼️ Immagine Copertina',
            'category': '🏷️ Categoria',
        }
        help_texts = {
            'title': 'Un titolo accattivante e chiaro (es: "Tour del Centro Storico", "Viaggio tra Arte e Storia")',
            'subtitle': 'Una frase che cattura l\'essenza del tour in poche parole',
            'description': 'Descrizione completa: cosa si vedrà, quanto dura, cosa lo rende speciale',
            'place': 'La città o area principale del tour',
            'default_image': 'Un\'immagine suggestiva che rappresenti il tour',
            'sub_tours': 'Puoi includere altri tour come sezioni di questo tour',
            'category': 'Il tipo di esperienza offerta',
        }

    def __init__(self, *args, **kwargs):
        request = kwargs.pop("request", None)
        super().__init__(*args, **kwargs)
        
        # Style the sub_tours field
        self.fields['sub_tours'].widget.attrs.update({
            'class': 'unfold-multiselect flex flex-col gap-2 p-2 border rounded-lg bg-white shadow-sm'
        })
        
        # Add placeholders
        if 'title' in self.fields:
            self.fields['title'].widget.attrs['placeholder'] = 'Es: Tour del Centro Storico di Roma'
        if 'subtitle' in self.fields:
            self.fields['subtitle'].widget.attrs['placeholder'] = 'Es: Alla scoperta dei monumenti più iconici'
        if 'description' in self.fields:
            self.fields['description'].widget.attrs['placeholder'] = (
                'Descrivi il tour in modo coinvolgente:\n'
                '- Cosa si vedrà\n'
                '- Durata stimata\n'
                '- Cosa lo rende speciale\n'
                '- A chi è consigliato'
            )
        if 'place' in self.fields:
            self.fields['place'].widget.attrs['placeholder'] = 'Es: Roma'

        # Handle popup creation for internal tours
        if request and "_popup" in request.GET:
            self.fields['category'].initial = 'INSIDE'
            self.fields['category'].disabled = True
            self.fields['category'].widget = forms.HiddenInput()
            self.fields['is_subtour'].initial = True


# ============================================================================
# INLINE ADMINS
# ============================================================================

class UnfoldNestedStackedInline(UnfoldStackedInline, nested_admin.NestedStackedInline):
    """Base class for nested stacked inlines with Unfold styling"""
    pass


class UnfoldNestedTabularInline(UnfoldStackedInline, nested_admin.NestedTabularInline):
    """Base class for nested tabular inlines with Unfold styling"""
    pass


class WaypointAdmin(UnfoldNestedStackedInline):
    """
    Inline admin per i Punti di Interesse all'interno di un Tour
    """
    model = Waypoint
    form = WaypointForm
    extra = 0
    verbose_name = "Punto di Interesse"
    verbose_name_plural = "Punti di Interesse del Tour"
    readonly_fields = ['display_existing_images']
    
    def get_queryset(self, request):
        """Filter waypoints: users only see their own tour waypoints"""
        qs = super().get_queryset(request)
        
        if not request.user.is_superuser:
            qs = qs.filter(tour__user=request.user)
        
        return qs
    
    # Organized fieldsets with clear descriptions
    fieldsets = (
        ('📍 Informazioni Base', {
            'fields': ('title', 'description'),
            'description': (
                '<div style="background: #f0f9ff; padding: 12px; border-radius: 6px; margin-bottom: 12px;">'
                '<strong>💡 Suggerimento:</strong> Inizia con un titolo chiaro e una descrizione breve. '
                'Aggiungerai i dettagli dopo.'
                '</div>'
            )
        }),
        ('🗺️ Posizione sulla Mappa', {
            'fields': ('place', 'coordinates',),
            'description': (
                '<div style="background: #fef3c7; padding: 12px; border-radius: 6px; margin-bottom: 12px;">'
                '<strong>📌 Come selezionare:</strong> Clicca sulla mappa nel punto esatto dove si trova il luogo. '
                'Puoi trascinare il marker per regolarne la posizione.'
                '</div>'
            )
        }),
        ('🖼️ Immagini', {
            'fields': ('uploaded_images', 'display_existing_images'),
            'classes': ('collapse',),
            'description': (
                '<div style="background: #f0fdf4; padding: 12px; border-radius: 6px; margin-bottom: 12px;">'
                '<strong>📷 Consiglio:</strong> Carica 3-5 immagini di buona qualità che mostrino il luogo '
                'da diverse angolazioni. Le foto aiutano i visitatori a riconoscere il posto!'
                '</div>'
            )
        }),
        ('📝 Descrizione Dettagliata', {
            'fields': ('readme_text',),
            'classes': ('collapse',),
            'description': (
                '<div style="background: #fae8ff; padding: 12px; border-radius: 6px; margin-bottom: 12px;">'
                '<strong>✍️ Scrivi con Markdown:</strong> Usa la formattazione per rendere il testo più leggibile. '
                'Puoi aggiungere titoli, elenchi puntati, grassetto, corsivo, ecc.'
                '</div>'
            )
        }),
        ('🎬 Contenuti Multimediali (Opzionale)', {
            'fields': ('pdf_item', 'video_item', 'audio_item'),
            'classes': ('collapse',),
            'description': (
                '<div style="background: #ede9fe; padding: 12px; border-radius: 6px; margin-bottom: 12px;">'
                '<strong>🎥 Opzionale ma consigliato:</strong> Aggiungi contenuti extra per arricchire l\'esperienza. '
                'Un PDF con info storiche, un video o una guida audio rendono il tour più completo.'
                '</div>'
            )
        }),
    )
    
    @admin.display(description="🖼️ Galleria Immagini")
    def display_existing_images(self, obj):
        """Display existing images in a nice gallery format"""
        if not obj or not obj.pk:
            return mark_safe(
                '<div style="background: #fef3c7; padding: 12px; border-radius: 6px; border-left: 4px solid #f59e0b;">'
                '<p class="text-sm" style="margin: 0;">⚠️ Salva prima il punto di interesse per poter caricare le immagini</p>'
                '</div>'
            )
        
        images = WaypointViewImage.objects.filter(waypoint=obj)
        
        if not images.exists():
            return mark_safe(
                '<div style="background: #f3f4f6; padding: 12px; border-radius: 6px;">'
                '<p class="text-sm text-gray-500" style="margin: 0;">📷 Nessuna immagine caricata ancora</p>'
                '</div>'
            )
        
        # Build gallery HTML
        html_parts = [
            '<div style="background: white; padding: 16px; border-radius: 8px; border: 1px solid #e5e7eb;">',
            f'<p style="margin: 0 0 12px 0; font-weight: 600; color: #374151;">📷 {images.count()} immagini caricate</p>',
            '<div class="flex flex-wrap gap-4" style="display: flex; flex-wrap: wrap; gap: 16px;">'
        ]
        
        for img in images:
            app_label = WaypointViewImage._meta.app_label
            model_name = WaypointViewImage._meta.model_name
            
            try:
                change_url = reverse(f'admin:{app_label}_{model_name}_change', args=[img.pk])
                delete_link = (
                    f'<a href="{change_url}" '
                    f'class="text-red-600 hover:text-red-800 dark:text-red-400 dark:hover:text-red-300 text-xs font-medium" '
                    f'target="_blank" style="color: #dc2626; font-size: 0.75rem; font-weight: 500;">🗑️ Gestisci</a>'
                )
            except:
                delete_link = ''
            
            img_url = f"/stream_minio_resource/?tour={img.waypoint.tour.pk}&waypoint={img.waypoint.pk}&file={img.image.name}"
            
            html_parts.append(f'''
                <div class="relative group border rounded-lg overflow-hidden shadow-sm hover:shadow-md transition-shadow" 
                     style="width: 200px; border: 1px solid #e5e7eb; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);">
                    <img src="{img_url}" 
                         alt="View image" 
                         onclick="window.open('{img_url}', '_blank')"
                         style="width: 100%; height: 160px; object-fit: cover; cursor: pointer;"
                         title="Clicca per vedere l'immagine a schermo intero"
                    />
                    <div style="padding: 8px; background: white; display: flex; justify-content: space-between; align-items: center;">
                        <span style="font-size: 0.75rem; color: #6b7280;">ID: {img.pk}</span>
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


# ============================================================================
# MAIN TOUR ADMIN
# ============================================================================

class TourAdmin(nested_admin.NestedModelAdmin, ModelAdmin):
    """
    Amministrazione principale per i Tour
    """
    show_facets = admin.ShowFacets.ALLOW
    hide_ordering_field = True
    compressed_fields = True
    
    list_display = ('title', 'place', 'category', 'status_badge', 'creation_time', 'user')
    readonly_fields = ['user', 'creation_time', 'status_info']
    list_filter = ['category', 'status', 'place', 'creation_time']
    search_fields = ('title', 'subtitle', 'description', 'place')
    date_hierarchy = 'creation_time'
    form = TourForm
    
    # Enhanced fieldsets with helpful descriptions and visual organization
    fieldsets = (
        (None, {
            'fields': ('status_info',),
            'classes': ('wide',),
        }),
        ('🎯 Informazioni Principali', {
            'fields': ('title', 'subtitle', 'category'),
            # 'description': (
            #     '<div style="background: #dbeafe; padding: 16px; border-radius: 8px; margin-bottom: 16px; border-left: 4px solid #3b82f6;">'
            #     '<h4 style="margin: 0 0 8px 0; color: #1e40af;">👋 Benvenuto nella creazione del tour!</h4>'
            #     '<p style="margin: 0;">Inizia con le informazioni base: dai un <strong>titolo accattivante</strong> '
            #     'e scegli la <strong>categoria</strong> più appropriata. Il sottotitolo è opzionale ma consigliato.</p>'
            #     '</div>'
            # )
        }),
        ('📝 Descrizione Completa', {
            'fields': ('description',),
            # 'description': (
            #     '<div style="background: #f0fdf4; padding: 12px; border-radius: 6px; margin-bottom: 12px;">'
            #     '<strong>💡 Cosa scrivere:</strong> Racconta cosa rende speciale questo tour, cosa si vedrà, '
            #     'quanto dura (indicativamente), e a chi è consigliato.'
            #     '</div>'
            # )
        }),
        ('📍 Posizione e Area', {
            'fields': ('place', 'coordinates'),
            # 'description': (
            #     '<div style="background: #fef3c7; padding: 12px; border-radius: 6px; margin-bottom: 12px;">'
            #     '<strong>🗺️ Posizione:</strong> Indica la località principale e seleziona sulla mappa '
            #     'il punto di partenza o il centro dell\'area del tour.'
            #     '</div>'
            # )
        }),
        ('🖼️ Immagine di Copertina', {
            'fields': ('default_image',),
            # 'description': (
            #     '<div style="background: #fae8ff; padding: 12px; border-radius: 6px; margin-bottom: 12px;">'
            #     '<strong>📸 Suggerimento:</strong> Scegli un\'immagine rappresentativa e di qualità. '
            #     'Questa sarà la prima cosa che vedranno gli utenti!'
            #     '</div>'
            # )
        }),
        ('🔗 Tour Interni (Opzionale)', {
            'fields': ('sub_tours',),
            'classes': ('collapse',),
            # 'description': (
            #     '<div style="background: #ede9fe; padding: 12px; border-radius: 6px; margin-bottom: 12px;">'
            #     '<strong>ℹ️ Tour interni:</strong> Se questo tour è composto da più sezioni, '
            #     'puoi includere altri tour come sotto-tour. Lascia vuoto se non necessario.'
            #     '</div>'
            # )
        }),
        ('⚙️ Informazioni di Sistema', {
            'fields': ('user', 'creation_time', 'status', 'is_subtour'),
            'classes': ('collapse',),
            'description': 'Informazioni tecniche gestite automaticamente dal sistema'
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
        js = [
            'https://code.jquery.com/jquery-3.6.0.min.js', 
            'admin/js/init_maps.js',
            'admin/js/init_markdown_editor.js',
            'admin/js/hide_waypoint_coordinates.js',
            'admin/js/refresh_subtours_checkboxes.js',
            'admin/js/loader.js'
        ]
    
    @admin.display(description="Status")
    def status_badge(self, obj):
        """Display status with colored badge"""
        status_colors = {
            'READY': '#3b82f6',      # Blue
            'ENQUEUED': '#f59e0b',   # Amber
            'BUILDING': '#8b5cf6',   # Purple
            'FAILED': '#ef4444',      # Red
        }
        status_labels = {
            'READY': '✅ Pronto',
            'ENQUEUED': '⏳ In Coda',
            'BUILDING': '🔨 In Costruzione',
            'FAILED': '❌ Errore',
        }
        color = status_colors.get(obj.status, '#6b7280')
        label = status_labels.get(obj.status, obj.status)
        
        return format_html(
            '<span style="background: {}; color: white; padding: 4px 12px; '
            'border-radius: 12px; font-size: 0.75rem; font-weight: 600; '
            'display: inline-block;">{}</span>',
            color, label
        )
    
    @admin.display(description="Stato del Tour")
    def status_info(self, obj):
        """Display comprehensive status information"""
        # if not obj or not obj.pk:
        #     return mark_safe(
        #         '<div style="background: #dbeafe; padding: 16px; border-radius: 8px; border-left: 4px solid #3b82f6;">'
        #         '<h3 style="margin: 0 0 8px 0; color: #1e40af;">🆕 Nuovo Tour</h3>'
        #         '<p style="margin: 0;">Stai creando un nuovo tour. Compila i campi sottostanti e aggiungi i punti di interesse.</p>'
        #         '</div>'
        #     )
        
        status_info = {
            "READY": {
                "color": "#dbeafe",
                "border": "#3b82f6",
                "title": "✅ Pronto per la Pubblicazione",
                "message": "Il tour è completo e pronto per essere pubblicato.",
                "action": "Verrà elaborato e pubblicato automaticamente.",
            },
            "ENQUEUED": {
                "color": "#fef3c7",
                "border": "#f59e0b",
                "title": "⏳ In Coda",
                "message": "Il tour è in coda per essere elaborato.",
                "action": "Attendi, sarà processato a breve. Non modificare durante questa fase.",
            },
            "BUILDING": {
                "color": "#f3e8ff",
                "border": "#8b5cf6",
                "title": "🔨 In Costruzione",
                "message": "Il tour è in fase di elaborazione.",
                "action": "Non modificare il tour durante questa fase. Il processo potrebbe richiedere alcuni minuti.",
            },
            "FAILED": {
                "color": "#fee2e2",
                "border": "#ef4444",
                "title": "❌ Errore",
                "message": "Si è verificato un errore durante l'elaborazione del tour.",
                "action": "Controlla i dati inseriti o contatta l'assistenza.",
            },
            "BUILT": {
                "color": "#048504d8",
                "border": "#83f302",
                "title": "✅ Pronto per l'uso",
                "message": "Modello Addestrato con successo e pronto per essere utilizzato.",
                "action": "Puoi iniziare a servire il tour ai visitatori.",
            },
        }
        
        info = status_info.get(obj.status)
        
        # Check if editable
        is_locked = obj.status in ['BUILDING', 'SERVING', 'ENQUEUED']
        lock_notice = ''
        if is_locked:
            lock_notice = (
                '<div style="background: #fee2e2; padding: 12px; border-radius: 6px; margin-top: 12px; border-left: 4px solid #ef4444;">'
                '<strong>🔒 Tour Bloccato:</strong> Non puoi modificare il tour in questo stato.'
                '</div>'
            )
        
        return mark_safe(
            f'<div style="background: {info["color"]}; padding: 16px; border-radius: 8px; '
            f'border-left: 4px solid {info["border"]}; margin-bottom: 20px;">'
            f'<h3 style="margin: 0 0 8px 0;">{info["title"]}</h3>'
            f'<p style="margin: 0 0 8px 0;"><strong>{info["message"]}</strong></p>'
            f'<p style="margin: 0; font-size: 0.875rem; opacity: 0.8;">{info["action"]}</p>'
            f'{lock_notice}'
            f'</div>'
        )
        
    def get_form(self, request, obj=None, **kwargs):
        Form = super().get_form(request, obj, **kwargs)

        def form_wrapper(*args, **kw):
            kw["request"] = request
            return Form(*args, **kw)

        return form_wrapper

    def formfield_for_manytomany(self, db_field, request, **kwargs):
        """Customize sub_tours field to show only available tours"""
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
        """Filter queryset: non-superusers see only their tours, excluding subtours"""
        qs = super().get_queryset(request)
        qs = qs.filter(is_subtour=False)
        
        if not request.user.is_superuser:
            qs = qs.filter(user=request.user)

        return qs

    def save_model(self, request, obj, form, change):
        """Auto-assign user on creation and update status on edit"""
        if not change:
            obj.user = request.user
        if change:
            obj.status = "READY"
        super().save_model(request, obj, form, change)

    def get_changeform_initial_data(self, request):
        """Set initial data for new tours"""
        initial = super().get_changeform_initial_data(request)
        initial['user'] = request.user.pk
        return initial

    def save_related(self, request, form, formsets, change):
        """Handle sub_tours relationships"""
        super().save_related(request, form, formsets, change)

        for subtour in form.instance.sub_tours.all():
            if not subtour.is_subtour:
                subtour.is_subtour = True
                subtour.save()
            if form.instance not in subtour.parent_tours.all():
                subtour.parent_tours.add(form.instance)

    def has_change_permission(self, request, obj=None):
        """Prevent editing tours in certain states"""
        has_permission = super().has_change_permission(request, obj)
        if not has_permission:
            return False
        if obj is None:
            return True
        if obj.status in ['BUILDING', 'SERVING', 'ENQUEUED']:
            return False
        return True

    def has_delete_permission(self, request, obj=None):
        """Prevent deleting tours in certain states or by other users"""
        has_permission = super().has_delete_permission(request, obj)
        if not has_permission:
            return False
        if obj is None:
            return True
        if obj.status in ['SERVING', 'BUILDING', 'ENQUEUED']:
            return False
        if not request.user.is_superuser and obj.user != request.user:
            return False
        return True


# ============================================================================
# SIMPLE MODEL ADMINS
# ============================================================================

class WaypointViewImageAdmin(ModelAdmin):
    """Admin for managing waypoint images"""
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


# class ReviewAdmin(ModelAdmin):
#     """Admin for managing tour reviews"""
#     list_display = ('tour', 'user', 'rating', 'created_at')
#     list_filter = ('rating', 'created_at')
#     search_fields = ('tour__title', 'user__username', 'comment')
#     date_hierarchy = 'created_at'
#     readonly_fields = ('created_at',)

# ============================================================================
# REGISTER MODELS
# ============================================================================

# admin.site.register(Review, ReviewAdmin)
admin.site.register(Tour, TourAdmin)
admin.site.register(WaypointViewImage, WaypointViewImageAdmin)

# Customize admin site header and title
admin.site.site_header = "🗺️ Tour Management System"
admin.site.site_title = "Tour Admin"
admin.site.index_title = "Benvenuto nel pannello di gestione tour"

# FIXARE FILTRO SU WAYPOINT PER IMMAGINI!!!!!!!!!!!!!!!!!!!!!!!!!!!!!