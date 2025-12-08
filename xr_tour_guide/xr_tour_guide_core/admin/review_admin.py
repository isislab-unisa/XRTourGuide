from ..models import Review
from django.contrib import admin
from unfold.admin import ModelAdmin
from django.db.models import Q

class ReviewAdmin(ModelAdmin):
    list_display = ("tour", "user", "timestamp")
    readonly_fields = ("user", "timestamp", "rating", "comment", "tour")
    search_fields = ('comment', )
    model = Review

    def get_queryset(self, request):
        qs = super().get_queryset(request)
        if not request.user.is_superuser:
            qs = qs.filter(Q(user=request.user) | Q(tour__user=request.user))
        return qs
    
    def has_change_permission(self, request, obj=None):
        has_permission = super().has_change_permission(request, obj)
        if not has_permission:
            return False
        if obj is None:
            return True
        return True
    
    def has_delete_permission(self, request, obj=None):
        has_permission = super().has_delete_permission(request, obj)
        if not has_permission:
            return False
        if obj is None:
            return True
        return True

admin.site.register(Review, ReviewAdmin)