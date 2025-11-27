from django.contrib import admin
from django import forms
from ..models import Waypoint, WaypointViewImage
from django.forms.widgets import ClearableFileInput
from django.utils.safestring import mark_safe
from django.core.files.base import ContentFile

class MultipleClearableFileInput(ClearableFileInput):
    
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


class WaypointForm(forms.ModelForm):
    
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
        
        if self.instance and self.instance.pk and self.instance.readme_item:
            try:
                self.fields['readme_text'].initial = self.instance.readme_item.read().decode('utf-8')
            except Exception as e:
                print(f"Error loading readme: {e}")

        if 'coordinates' in self.fields:
            old_classes = self.fields['coordinates'].widget.attrs.get('class', '')
            new_classes = f"{old_classes} waypoint-coordinates-field".strip()
            self.fields['coordinates'].widget.attrs['class'] = new_classes
        
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


