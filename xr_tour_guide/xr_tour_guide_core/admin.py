from django.contrib import admin
import nested_admin
# from unfold.admin import StackedInline as UnfoldStackedInline
# from unfold.admin import TabularInline as UnfoldTabularInline


# class UnfoldNestedStackedInline(UnfoldStackedInline, nested_admin.NestedStackedInline):
#     pass

# class UnfoldNestedTabularInline(UnfoldTabularInline, nested_admin.NestedTabularInline):
#     pass

admin.site.site_header = "🗺️ Tour Management System"
admin.site.site_title = "Tour Admin"
admin.site.index_title = "Benvenuto nel pannello di gestione tour"