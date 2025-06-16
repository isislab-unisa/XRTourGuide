from django.core.management.base import BaseCommand
from django.contrib.auth.models import Group, Permission
from django.contrib.contenttypes.models import ContentType

class Command(BaseCommand):
    help = 'Crea i gruppi Author e Student con i permessi associati'

    def handle(self, *args, **kwargs):
        from xr_tour_guide_core.models import Tour, Waypoint, WaypointViewImage

        author_group, _ = Group.objects.get_or_create(name='User')

        tour_ct = ContentType.objects.get_for_model(Tour)
        tour_perms = Permission.objects.filter(content_type=tour_ct)

        waypoint_ct = ContentType.objects.get_for_model(Waypoint)
        waypoint_perms = Permission.objects.filter(content_type=waypoint_ct)

        image_ct = ContentType.objects.get_for_model(WaypointViewImage)
        image_perms = Permission.objects.filter(content_type=image_ct)

        all_perms = list(tour_perms) + list(waypoint_perms) + list(image_perms)

        author_group.permissions.set(all_perms)

        self.stdout.write(self.style.SUCCESS('Gruppo "User" creato e permessi assegnati con successo.'))
