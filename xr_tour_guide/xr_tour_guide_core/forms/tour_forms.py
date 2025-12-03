from django import forms
from ..models import Tour

from django.urls import reverse
from django.utils.safestring import mark_safe
from django.utils.html import format_html

class ClickableCheckboxSelectMultiple(forms.CheckboxSelectMultiple):
    
    def __init__(self, model_name='tour', app_label='xr_tour_guide_core', *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.model_name = model_name
        self.app_label = app_label
    
    def create_option(self, name, value, label, selected, index, subindex=None, attrs=None):
        option = super().create_option(name, value, label, selected, index, subindex, attrs)
        
        if value:
            print(f"VALUE: {value}", flush=True)
            change_url = reverse(f'admin:{self.app_label}_{self.model_name}_change', args=[value])
            
            original_label = option['label']
            option['label'] = format_html(
                '{} <a href="{}" target="_blank" style="margin-left: 8px; color: #3b82f6; text-decoration: none; font-weight: 500;" '
                'onclick="event.stopPropagation();">✏️ Modifica</a>',
                original_label,
                change_url
            )
        
        return option
    
    class Media:
        css = {
            'all': ['admin/css/clickable_checkboxes.css']
        }

class TourForm(forms.ModelForm):
    
    class Meta:
        model = Tour
        fields = "__all__"
        widgets = {
            'is_subtour': forms.HiddenInput(),
            'sub_tours': ClickableCheckboxSelectMultiple(
                model_name='tour',
                app_label='xr_tour_guide_core'
            ),
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
            'sub_tours': 'Seleziona i tour interni. Clicca su "✏️ Modifica" per aprire e modificare ciascun tour.',
            'category': 'Il tipo di esperienza offerta',
        }

    def __init__(self, *args, **kwargs):
        request = kwargs.pop("request", None)
        super().__init__(*args, **kwargs)
        
        self.fields['sub_tours'].widget.attrs.update({
            'class': 'unfold-multiselect flex flex-col gap-2 p-2 border rounded-lg bg-white shadow-sm'
        })
        
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

        if request and "_popup" in request.GET and not self.instance.pk:
            self.fields['category'].initial = 'INSIDE'
            self.fields['category'].disabled = True
            self.fields['category'].widget = forms.HiddenInput()
            self.fields['is_subtour'].initial = True