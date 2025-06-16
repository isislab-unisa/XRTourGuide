from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.core.files.base import ContentFile
from ...models import Tour, Waypoint, WaypointViewImage
from PIL import Image, ImageDraw, ImageFont
from io import BytesIO
from django.core.files.base import ContentFile

def create_dummy_image(idx_wp, idx_img):
    img = Image.new("RGB", (400, 300), color=(255, 255, 255))
    draw = ImageDraw.Draw(img)

    draw.rectangle((50, 50, 350, 250), fill=(200, 200, 255), outline="blue")
    draw.text((60, 120), f"WP {idx_wp} - IMG {idx_img}", fill="black")

    buffer = BytesIO()
    img.save(buffer, format="JPEG")
    buffer.seek(0)

    return ContentFile(buffer.read(), name=f"image_{idx_wp}_{idx_img}.jpg")

User = get_user_model()

class Command(BaseCommand):
    help = 'Create one tour with its waypoints and images at a time'

    tours_data = [
        {"title": "Tour Outside 1", "subtitle": "Sub 1", "place": "Place A", "category": "OUTSIDE"},
        {"title": "Tour Outside 2", "subtitle": "Sub 2", "place": "Place B", "category": "OUTSIDE"},
        {"title": "Tour Inside 1", "subtitle": "Sub 3", "place": "Place C", "category": "INSIDE"},
    ]

    def handle(self, *args, **kwargs):
        user, created = User.objects.get_or_create(
            username='groot',
            defaults={
                'email': 'root@example.com',
                'is_superuser': True,
                'is_staff': True
            }
        )
        if created:
            user.set_password('groot')
            user.save()
            self.stdout.write(self.style.SUCCESS("Utente root creato e promosso a superuser"))
        else:
            self.stdout.write("Utente root già esistente")

        for tour_data in self.tours_data:
            dummy_content = ContentFile(b"image content here", name=f"test_image.jpg")
            tour = Tour.objects.filter(title=tour_data["title"]).first()
            if not tour:
                tour = Tour.objects.create(
                    title=tour_data["title"],
                    subtitle=tour_data["subtitle"],
                    place=tour_data["place"],
                    category=tour_data["category"],
                    description="Descrizione di esempio",
                    user=user,
                    coordinates="41.9028,12.4964",
                    default_image=dummy_content
                )
                self.stdout.write(self.style.SUCCESS(f"Creato tour: {tour.title}"))
            else:
                self.stdout.write(f"Tour già esistente: {tour.title}")

            waypoints = Waypoint.objects.filter(tour=tour)
            if waypoints.exists():
                self.stdout.write(f"Waypoint già esistenti per tour {tour.title}")
            else:
                for idx_wp in range(2):
                    waypoint = Waypoint.objects.create(
                        title=f"Waypoint {idx_wp + 1} - {tour.title}",
                        tour=tour,
                        coordinates="41.9028,12.4964",
                        description=f"Descrizione waypoint {idx_wp + 1}",
                        model_path="model.obj"
                    )
                    self.stdout.write(f"  Creato waypoint: {waypoint.title}")

                    images = WaypointViewImage.objects.filter(waypoint=waypoint)
                    if images.exists():
                        self.stdout.write(f"    Immagini già presenti per waypoint {waypoint.title}")
                    else:
                        for idx_img in range(2):
                            dummy_content = ContentFile(b"image content here", name=f"image_{idx_wp}_{idx_img}.jpg")
                            image = WaypointViewImage(waypoint=waypoint)
                            image.save()
                            image.image.save(f"dummy_image_{idx_wp}_{idx_img}.jpg", dummy_content)
                            image.save()
                            self.stdout.write(f"    Immagine creata: {image.image.name}")

