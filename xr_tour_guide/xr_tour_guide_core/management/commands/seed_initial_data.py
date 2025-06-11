from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from ...models import Tour, Waypoint, Tag, WaypointViewImage
from django.core.files.base import ContentFile
from django.utils import timezone
import random

User = get_user_model()

class Command(BaseCommand):
    help = 'Seed initial root user, tours, waypoints and images'

    def handle(self, *args, **kwargs):
        if not User.objects.filter(username='root').exists():
            user = User.objects.create_user(username='root', email='root@example.com', password='rootpass')
            user.is_superuser = True
            user.is_staff = True
            user.save()
            self.stdout.write(self.style.SUCCESS("Utente root creato e promosso a superuser"))
        else:
            self.stdout.write("Utente root già esistente")

        tag, _ = Tag.objects.get_or_create(name="DefaultTag")

        tours_data = [
            {"title": "Tour Outside 1", "subtitle": "Sub 1", "place": "Place A", "category": "OUTSIDE"},
            {"title": "Tour Outside 2", "subtitle": "Sub 2", "place": "Place B", "category": "OUTSIDE"},
            {"title": "Tour Inside 1", "subtitle": "Sub 3", "place": "Place C", "category": "INSIDE"},
        ]

        for data in tours_data:
            if not Tour.objects.filter(title=data["title"]).exists():
                tour = Tour.objects.create(
                    title=data["title"],
                    subtitle=data["subtitle"],
                    place=data["place"],
                    category=data["category"],
                    description="Descrizione di esempio",
                    user=User.objects.get(username="root"),
                    coordinates="41.9028,12.4964"
                )
                self.stdout.write(f"Creato tour: {tour.title}")

                for j in range(2):
                    waypoint = Waypoint.objects.create(
                        title=f"Waypoint {j+1} - {tour.title}",
                        tour=tour,
                        coordinates="41.9028,12.4964",
                        description=f"Descrizione waypoint {j+1}",
                        model_path="model.obj",
                        tag=tag
                    )
                    self.stdout.write(f"  Creato waypoint: {waypoint.title}")

                    for i in range(2):
                        dummy_content = ContentFile(b"image content here", name=f"image_{j}_{i}.jpg")
                        image = WaypointViewImage.objects.create(
                            waypoint=waypoint,
                        )
                        image.image.save(f"dummy_image_{j}_{i}.jpg", dummy_content, save=True)
                        self.stdout.write(f"    Immagine creata: {image.image.name}")
            else:
                self.stdout.write(f"Tour già esistente: {data['title']}")

                # for waypoint in Tour.objects.get(title=data["title"]).waypoint_set.all():
                #     self.stdout.write(f"  Waypoint esistente: {waypoint.title}")    