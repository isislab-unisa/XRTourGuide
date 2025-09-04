from django.contrib import admin
from django import forms
from location_field.widgets import LocationWidget
from location_field.models.plain import PlainLocationField
import nested_admin
from unfold.admin import ModelAdmin
from unfold.admin import StackedInline as UnfoldStackedInline
from unfold.admin import TabularInline as UnfolTabularInline
from .models import Tour, Waypoint, WaypointViewImage, Review
from django.forms.widgets import ClearableFileInput
from django.utils.safestring import mark_safe
from .models import CustomUser
from django.contrib.auth.admin import UserAdmin
from django.core.files.base import ContentFile


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
                Upload Images
                {input_html}
            </label>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-base-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1M12 12v6m0 0L8 16m4 2l4-2m-6-6h6m-3-4v4" />
            </svg>
        </div>
        """)

class MultipleFileField(forms.FileField):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault('widget', MultipleClearableFileInput())
        super().__init__(*args, **kwargs)

    def clean(self, data, initial=None):
        single_file_clean = super().clean
        if isinstance(data, (list, tuple)):
            return [single_file_clean(d, initial) for d in data]
        return [single_file_clean(data, initial)]
    
    def save(self, commit=True):
        instance = super().save(commit=commit)
        print("[DEBUG] Saving form for Cromo_View", instance)

        uploaded_files = self.cleaned_data.get('uploaded_images')
        print("[DEBUG] Uploaded files:", uploaded_files)

        if instance.pk and uploaded_files:
            for uploaded_file in uploaded_files:
                WaypointViewImage.objects.create(cromo_view=instance, image=uploaded_file)

        return instance


class WaypointForm(forms.ModelForm):
    uploaded_images = forms.FileField(
        required=False,
        label='Views',
        widget=MultipleClearableFileInput()
    )
    
    readme_text = forms.CharField(
        widget=forms.Textarea(attrs={'class': 'markdown-editor', 'rows': 10}),
        label="Readme (Markdown)",
        required=False,
    )
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if 'coordinates' in self.fields:
            old_classes = self.fields['coordinates'].widget.attrs.get('class', '')
            new_classes = f"{old_classes} waypoint-coordinates-field".strip()
            self.fields['coordinates'].widget.attrs['class'] = new_classes

    def clean_uploaded_images(self):
        field_name = self.add_prefix('uploaded_images')
        return self.files.getlist(field_name)
    
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
        fields = ['title', 'coordinates', 'description', 'pdf_item', 'video_item', 'audio_item']

class UnfoldNestedStackedInline(UnfoldStackedInline, nested_admin.NestedStackedInline):
    pass

class UnfoldNestedTabularInline(UnfoldStackedInline, nested_admin.NestedTabularInline):
    pass

# class WaypointLinkInline(UnfoldNestedStackedInline):
#     model = WaypointLink
#     extra = 1
    
class WaypointAdmin(UnfoldNestedStackedInline):
    model = Waypoint
    form = WaypointForm
    extra = 1
    # formfield_overrides = {
    #     PlainLocationField: {"widget": LocationWidget},
    # }

    class Media:
        js = [
            'https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.js',
            'admin/js/hide_waypoint_coordinates.js',
            'admin/js/init_markdown_editor.js',
        ]
        css = {
            'all': ['https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.css']
        }
    
    def save_related(self, request, form, formsets, change):
        super().save_related(request, form, formsets, change)

        for formset in formsets:
            for inline_form in formset.forms:
                if not hasattr(inline_form, 'cleaned_data'):
                    continue
                uploaded_files = inline_form.cleaned_data.get('uploaded_images', [])
                print("uploaded_files per form:", uploaded_files)
                if uploaded_files:
                    waypoint = inline_form.instance
                    print("Salvo per waypoint:", waypoint)
                    for uploaded_file in uploaded_files:
                        WaypointViewImage.objects.create(waypoint=waypoint, image=uploaded_file)

from django import forms

class TourForm(forms.ModelForm):
    class Meta:
        model = Tour
        fields = "__all__"

    def __init__(self, *args, **kwargs):
        request = kwargs.pop("request", None)
        super().__init__(*args, **kwargs)

        if request and "_popup" in request.GET:
            self.fields['category'].initial = 'INSIDE'
            self.fields['category'].disabled = True

class TourAdmin(nested_admin.NestedModelAdmin, ModelAdmin):
    fields = ('category', 'title', 'subtitle', 'description', 'place', 'coordinates', 'default_image', 'sub_tours')
    list_display = ('title', 'creation_time', 'category', 'place', 'user', 'status')
    readonly_fields = ['user', 'creation_time']
    list_filter = ['user', 'category', 'place']
    search_fields = ('title', 'description')
    date_hierarchy = 'creation_time'
    form = TourForm

    inlines = [WaypointAdmin]

    class Media:
        js = ['https://code.jquery.com/jquery-3.6.0.min.js', 'admin/js/hide_waypoint_coordinates.js']
    
    def get_form(self, request, obj=None, **kwargs):
        Form = super().get_form(request, obj, **kwargs)

        def form_wrapper(*args, **kw):
            kw["request"] = request
            return Form(*args, **kw)

        return form_wrapper
    
    formfield_overrides = {
        PlainLocationField: {"widget": LocationWidget},
    }

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        qs = qs.filter(parent_tours__isnull=True)
        if request.user.is_superuser:
            return qs
        return qs.filter(user=request.user)

    def formfield_for_manytomany(self, db_field, request, **kwargs):
        if db_field.name == "sub_tours":
            kwargs["queryset"] = Tour.objects.filter(category='INSIDE')
        return super().formfield_for_manytomany(db_field, request, **kwargs)

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

class ReviewAdmin(ModelAdmin):
    pass

admin.site.register(Review, ReviewAdmin)
admin.site.register(Tour, TourAdmin)
admin.site.register(WaypointViewImage, WaypointViewImageAdmin)
# admin.site.register(WaypointLink, WaypointLinkInline)