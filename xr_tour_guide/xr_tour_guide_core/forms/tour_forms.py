from django import forms
from ..models import Tour

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

        if request and "_popup" in request.GET:
            self.fields['category'].initial = 'INSIDE'
            self.fields['category'].disabled = True
            self.fields['category'].widget = forms.HiddenInput()
            self.fields['is_subtour'].initial = True
