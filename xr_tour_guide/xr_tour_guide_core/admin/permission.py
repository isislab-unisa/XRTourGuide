from django.db.models import Q
from xr_tour_guide_core.models import TourCollaboratorRole

def can_view_tour(user, tour):
    """
    Check if the user can view the tour.
    """
    if user.is_superuser:
        return True
    if tour.user.id == user.id:
        return True
    
    return tour.collaborators.filter(user=user).exists()    

def can_edit_tour(user, tour):
    if not user or not user.is_authenticated:
        return False

    if user.is_superuser:
        return True

    if tour.user.id == user.id:
        return True

    return tour.collaborators.filter(user=user, role=TourCollaboratorRole.EDITOR).exists()

def visible_tours_queryset(user, queryset):
    if not user or not user.is_authenticated:
        return queryset.none()
    
    if user.is_superuser:
        return queryset
        
    return queryset.filter(
        Q(user=user) |
        Q(collaborators__user=user)
    ).distinct()

def can_delete_tour(user, tour):
    if not user or not user.is_authenticated:
        return False

    if user.is_superuser:
        return True

    return tour.user.id == user.id

def can_manage_tour_collaborators(user, tour):
    if not user or not user.is_authenticated:
        return False

    if user.is_superuser:
        return True

    return tour.user.id == user.id