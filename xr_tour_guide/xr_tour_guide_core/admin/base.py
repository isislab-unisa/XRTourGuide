"""
Base admin classes shared across all admin modules.
This file prevents circular imports.
"""
import nested_admin
from unfold.admin import StackedInline as UnfoldStackedInline
from unfold.admin import TabularInline as UnfoldTabularInline


class UnfoldNestedStackedInline(UnfoldStackedInline, nested_admin.NestedStackedInline):
    """
    Hybrid inline that combines Unfold styling with nested_admin functionality.
    Fixes method signature conflicts between the two parent classes.
    """
    def has_add_permission(self, request, obj=None):
        """Override to match Django's inline signature"""
        return super(UnfoldStackedInline, self).has_add_permission(request, obj)
    
    def has_change_permission(self, request, obj=None):
        """Override to match Django's inline signature"""
        return super(UnfoldStackedInline, self).has_change_permission(request, obj)
    
    def has_delete_permission(self, request, obj=None):
        """Override to match Django's inline signature"""
        return super(UnfoldStackedInline, self).has_delete_permission(request, obj)


class UnfoldNestedTabularInline(UnfoldTabularInline, nested_admin.NestedTabularInline):
    """
    Hybrid inline that combines Unfold styling with nested_admin functionality.
    Fixes method signature conflicts between the two parent classes.
    """
    def has_add_permission(self, request, obj=None):
        """Override to match Django's inline signature"""
        return super(UnfoldTabularInline, self).has_add_permission(request, obj)
    
    def has_change_permission(self, request, obj=None):
        """Override to match Django's inline signature"""
        return super(UnfoldTabularInline, self).has_change_permission(request, obj)
    
    def has_delete_permission(self, request, obj=None):
        """Override to match Django's inline signature"""
        return super(UnfoldTabularInline, self).has_delete_permission(request, obj)