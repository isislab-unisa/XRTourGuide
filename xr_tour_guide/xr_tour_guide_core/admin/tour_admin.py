from django.contrib import admin
from django import forms
import nested_admin
from unfold.admin import ModelAdmin
from ..models import Tour
from django.utils.safestring import mark_safe
from django.utils.html import format_html
from django.db import models
from ..forms.tour_forms import TourForm
from .waypoint_admin import WaypointAdmin
from django.contrib.admin.views.main import ChangeList
from django.utils.translation import gettext_lazy as _
from django.contrib import messages
from django.shortcuts import redirect

class TourAdmin(nested_admin.NestedModelAdmin, ModelAdmin):
    show_facets = admin.ShowFacets.ALLOW
    hide_ordering_field = True
    compressed_fields = True
    
    list_display = ('title', 'place', 'category', 'status_badge', 'creation_time', 'user')
    readonly_fields = ['user', 'creation_time', 'status_info', 'status_badge', 'status']
    list_filter = ['category', 'status', 'place', 'creation_time']
    search_fields = ('title', 'subtitle', 'description', 'place')
    date_hierarchy = 'creation_time'
    form = TourForm
    inlines = [WaypointAdmin]
    
    fieldsets = (
        (None, {
            'fields': ('status_info',),
            'classes': ('wide',),
        }),
        (_('🎯 Main Information'), {
            'fields': ('title', 'subtitle', 'category'),
        }),
        (_('📝 Full Description'), {
            'fields': ('description',),
        }),
        (_('📍 Location and Area'), {
            'fields': ('place', 'coordinates'),
        }),
        (_('🖼️ Cover Image'), {
            'fields': ('default_image',),
        }),
        (_('🔗 Internal Tours (Optional)'), {
            'fields': ('sub_tours',),
            'classes': ('collapse',),
        }),
        (_('⚙️ System Information'), {
            'fields': ('user', 'creation_time', 'status', 'is_subtour'),
            'classes': ('collapse',),
            'description': _('Technical information automatically managed by the system')
        }),
    )

    formfield_overrides = {
        models.ManyToManyField: {'widget': forms.CheckboxSelectMultiple},
    }
    
    widgets = {
        'is_subtour': forms.HiddenInput()
    }

    class Media:
        js = [
            'https://code.jquery.com/jquery-3.6.0.min.js', 
            'admin/js/init_maps.js',
            'admin/js/init_markdown_editor.js',
            'admin/js/hide_waypoint_coordinates.js',
            # 'admin/js/refresh_subtours_checkboxes.js',
            'admin/js/fix_minio_preview.js',
            'admin/js/loader.js',
            'admin/js/subtour_popup.js',
        ]
        css = {
            'all': [
                'admin/css/subtour_improved.css',
            ]
        }
        
    @admin.display(description=_("Status"))
    def status_badge(self, obj):
        status_colors = {
            'READY': '#3b82f6',
            'ENQUEUED': '#f59e0b',
            'BUILDING': '#8b5cf6',
            'FAILED': '#ef4444',
        }
        status_labels = {
            'READY': _('✅ Ready'),
            'ENQUEUED': _('⏳ Queued'),
            'BUILDING': _('🔨 Building'),
            'FAILED': _('❌ Error'),
        }
        color = status_colors.get(obj.status, '#6b7280')
        label = status_labels.get(obj.status, obj.status)
        
        return format_html(
            '<span style="background: {}; color: white; padding: 4px 12px; '
            'border-radius: 12px; font-size: 0.75rem; font-weight: 600; '
            'display: inline-block;">{}</span>',
            color, label
        )
    
    @admin.display(description=_("Tour Status"))
    def status_info(self, obj):
        status_info = {
            "READY": {
                "bg_light": "#dbeafe",
                "bg_dark": "#1e3a8a",
                "border_light": "#3b82f6",
                "border_dark": "#60a5fa",
                "title": _("✅ Ready for Publication"),
                "message": _("The tour is complete and ready to be published."),
                "action": _("It will be processed and published automatically."),
            },
            "ENQUEUED": {
                "bg_light": "#fef3c7",
                "bg_dark": "#78350f",
                "border_light": "#f59e0b",
                "border_dark": "#fbbf24",
                "title": _("⏳ Queued"),
                "message": _("The tour is queued for processing."),
                "action": _("Please wait, it will be processed shortly. Do not modify during this phase."),
            },
            "BUILDING": {
                "bg_light": "#f3e8ff",
                "bg_dark": "#581c87",
                "border_light": "#8b5cf6",
                "border_dark": "#a78bfa",
                "title": _("🔨 Building"),
                "message": _("The tour is being processed."),
                "action": _("Do not modify the tour during this phase. The process may take a few minutes."),
            },
            "FAILED": {
                "bg_light": "#fee2e2",
                "bg_dark": "#7f1d1d",
                "border_light": "#ef4444",
                "border_dark": "#f87171",
                "title": _("❌ Error"),
                "message": _("An error occurred while processing the tour."),
                "action": _("Check the entered data or contact support."),
            },
            "BUILT": {
                "bg_light": "#d1fae5",
                "bg_dark": "#065f46",
                "border_light": "#10b981",
                "border_dark": "#34d399",
                "title": _("✅ Ready for Use"),
                "message": _("Model successfully trained and ready to be used."),
                "action": _("You can start serving the tour to visitors."),
            },
        }
        
        info = status_info.get(obj.status)
        
        is_locked = obj.status in ['BUILDING', 'SERVING', 'ENQUEUED']
        lock_notice = ''
        if is_locked:
            lock_notice = f'''
                <div style="
                    background: light-dark(#fee2e2, #7f1d1d);
                    padding: 12px;
                    border-radius: 8px;
                    margin-top: 12px;
                    border-left: 4px solid light-dark(#ef4444, #f87171);
                    color: light-dark(#7f1d1d, #fecaca);
                ">
                    <strong>{_("🔒 Tour Locked:")}</strong> {_("You cannot modify the tour in this state.")}
                </div>
            '''
        
        return mark_safe(
            f'''<div style="
                background: light-dark({info["bg_light"]}, {info["bg_dark"]});
                padding: 16px;
                border-radius: 8px;
                border-left: 4px solid light-dark({info["border_light"]}, {info["border_dark"]});
                margin-bottom: 20px;
                color: light-dark(#1f2937, #f9fafb);
            ">
                <h3 style="margin: 0 0 8px 0; font-size: 1.125rem; font-weight: 600;">{info["title"]}</h3>
                <p style="margin: 0 0 8px 0; font-weight: 500;">{info["message"]}</p>
                <p style="margin: 0; font-size: 0.875rem; opacity: 0.8;">{info["action"]}</p>
                {lock_notice}
            </div>'''
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
        
        if not request.user.is_superuser:
            qs = qs.filter(user=request.user)

        return qs
    
    def changelist_view(self, request, extra_context=None):
        return super().changelist_view(request, extra_context)

    def get_changelist(self, request, **kwargs):
        
        class SubtourFilteredChangeList(ChangeList):
            def get_queryset(self, request):
                qs = super().get_queryset(request)
                return qs.filter(is_subtour=False)
        
        return SubtourFilteredChangeList

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

    def delete_model(self, request, obj):
        if obj.status in ['SERVING', 'BUILDING', 'ENQUEUED']:
            self.message_user(
                request, 
                _("❌ Non puoi eliminare questo tour perché è in uno stato bloccato."), 
                level=messages.ERROR
            )
        else:
            super().delete_model(request, obj)

    def change_view(self, request, object_id, form_url='', extra_context=None):
        obj = self.get_object(request, object_id)
        if obj and obj.status in ['BUILDING', 'SERVING', 'ENQUEUED']:
            self.message_user(
                request,
                _("❌ Non puoi modificare questo tour perché è in uno stato bloccato."),
                level=messages.ERROR
            )
            return redirect('admin:%s_%s_changelist' % (obj._meta.app_label, obj._meta.model_name))
        return super().change_view(request, object_id, form_url, extra_context)
    
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
        if not request.user.is_superuser and obj.user != request.user:
            return False
        return True

admin.site.register(Tour, TourAdmin)