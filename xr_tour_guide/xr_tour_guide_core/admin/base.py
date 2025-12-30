import nested_admin
from unfold.admin import StackedInline as UnfoldStackedInline
from unfold.admin import TabularInline as UnfoldTabularInline


class UnfoldNestedStackedInline(UnfoldStackedInline, nested_admin.NestedStackedInline):
    def has_add_permission(self, request, obj=None):
        return super(UnfoldStackedInline, self).has_add_permission(request, obj)
    
    def has_change_permission(self, request, obj=None):
        return super(UnfoldStackedInline, self).has_change_permission(request, obj)
    
    def has_delete_permission(self, request, obj=None):
        return super(UnfoldStackedInline, self).has_delete_permission(request, obj)


class UnfoldNestedTabularInline(UnfoldTabularInline, nested_admin.NestedTabularInline):
    def has_add_permission(self, request, obj=None):
        return super(UnfoldTabularInline, self).has_add_permission(request, obj)
    
    def has_change_permission(self, request, obj=None):
        return super(UnfoldTabularInline, self).has_change_permission(request, obj)
    
    def has_delete_permission(self, request, obj=None):
        return super(UnfoldTabularInline, self).has_delete_permission(request, obj)