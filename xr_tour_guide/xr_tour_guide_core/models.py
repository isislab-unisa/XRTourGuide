from django.db import models
from location_field.models.plain import PlainLocationField
import dotenv
from storages.backends.s3boto3 import S3Boto3Storage
from django.core.files.base import ContentFile
import os
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model

dotenv.load_dotenv()

def upload_to(instance, file_name):
    poi_id = instance.waypoint_view.waypoint.id
    tag = instance.waypoint_view.waypoint.tag.replace(" ", "_")
    tag = instance.tag.replace(" ", "_")
    storage = MinioStorage()
    elements = storage.bucket.objects.filter(Prefix=f"{poi_id}/data/test/{tag}/")
    c = 0
    for k in elements:
        c += 1
    
    if c == 0:
        return f"{poi_id}/data/test/{tag}/{file_name}"
    else:
        return f"{poi_id}/data/train/{tag}/{file_name}"

def upload_media_item(instance, file_name):
    poi_id = instance.waypoint.id
    storage = MinioStorage()
    file = ContentFile(instance.file.read())
    storage.save(f"{poi_id}/data/media/{file_name}", file)
    
def default_image(instance, file_name):
    return f"{instance.cromo_poi.id}/default_image/{instance.tag}/{file_name}"

class MinioStorage(S3Boto3Storage):
    bucket_name = os.getenv("AWS_STORAGE_BUCKET_NAME")
    custom_domain = False
    
class Tag(models.Model):
    name = models.CharField(max_length=64, null=False, blank=False, primary_key=True)
    
    class Meta:
        db_table = "Tag"
        verbose_name = "Tag"
        verbose_name_plural = "Tag"
        
    def __str__(self):
        return self.name

class Status(models.TextChoices):
    READY = "READY", "Ready"
    FAILED = "FAILED", "Failed"
    BUILDING = "BUILDING", "Building"
    BUILT = "BUILT", "Built"
    SERVING = "SERVING", "Serving"
    ENQUEUED = "ENQUEUED", "Enqueued"

class Category(models.TextChoices):
    INSIDE = "INSIDE", "Inside"
    OUTSIDE = "OUTSIDE", "Outside"
    THING = "THING", "Thing"
        
class TourQuerySet(models.QuerySet):
    def delete(self, *args, **kwargs):
        for obj in self:
            obj.delete()
        super().delete(*args, **kwargs)

class Tour(models.Model):
    title = models.CharField(max_length=200, blank=False, null=False)
    subtitle = models.CharField(max_length=200, blank=False, null=False)
    place = models.CharField(max_length=200, blank=False, null=False)
    coordinates = PlainLocationField(zoom=7, null=True, blank=True)
    category = models.CharField(
        max_length=20,
        choices=Category.choices,
        default=Category.INSIDE,
    )
    description = models.TextField()
    objects = TourQuerySet.as_manager()
    created_at = models.DateTimeField(null=True, blank=True)
    build_started_at = models.DateTimeField(null=True, blank=True)
    user = models.ForeignKey(get_user_model(), on_delete=models.SET_NULL, null=True, blank=True)
    creation_time = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    
    class Meta:
        db_table = "Tour"
        verbose_name = "Tour"
        verbose_name_plural = "Tours"
        # permissions = [
        #     ("can_create_cromo_poi", "Can create cromo_poi"),
        #     ("can_view_cromo_poi", "Can view cromo_poi"),
        # ]
        
    def __str__(self):
        return self.title
    
    def get_folder_name(self):
        return f"{self.pk}"
    
    def delete(self, *args, **kwargs):
        folder_name = self.get_folder_name() + "/"
        storage = MinioStorage()
        elements = storage.bucket.objects.filter(Prefix=folder_name)
        try:
            for k in elements:
                k.delete()
        except:
            objects = list(storage.bucket.objects.all())
            object_keys = [obj.key for obj in objects]
            raise Exception(f"La cartella {folder_name} non esiste. Oggetti presenti: {object_keys}")
        super().delete(*args, **kwargs)

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        
        if is_new:
            super().save(*args, **kwargs)

        folder_name = self.get_folder_name()

        storage = MinioStorage()
        keep_path = f"{folder_name}/.keep"
        if not storage.exists(keep_path):
            storage.save(keep_path, ContentFile(b""))

        if is_new:
            self.status = Status.READY
        
        super().save(*args, **kwargs)

class Waypoint(models.Model):
    title = models.CharField(max_length=200, blank=False, null=False)
    coordinates = PlainLocationField(zoom=7, null=True, blank=True)
    tour = models.ForeignKey(Tour, on_delete=models.CASCADE, related_name='waypoints')
    description = models.TextField()
    model_path = models.CharField(max_length=200, blank=False, null=False)
    class Meta:
        db_table = "Waypoint"
        verbose_name = "Waypoint"
        verbose_name_plural = "Waypoints"

    def __str__(self):
        return self.title

class WaypointView(models.Model):
    tag = models.ForeignKey(Tag, on_delete=models.SET_NULL, null=True, blank=False)
    timestamp = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    build_started_at = models.DateTimeField(null=True, blank=True)
    default_image = models.ImageField(upload_to=default_image, storage=MinioStorage(), null=True, blank=True)
    waypoint = models.ForeignKey(Waypoint, on_delete=models.CASCADE, related_name='views', null=True, blank=True)
    
    class Meta:
        db_table = "WaypointView"
        verbose_name = "WaypointView"
        verbose_name_plural = "WaypointViews"
        
    def __str__(self):
        return f"{self.tag}"

class WaypointViewImage(models.Model):
    waypoint_view = models.ForeignKey(WaypointView, related_name='images', on_delete=models.CASCADE, null=True, blank=True)
    image = models.ImageField(upload_to=upload_to, storage=MinioStorage(), null=True, blank=True)
    
    def __str__(self):
        return f"Image for {self.cromo_view.tag}"
    
class MediaItem(models.Model):
    type = models.CharField(max_length=20, blank=False, null=False)
    item = models.FileField(upload_to=upload_media_item, storage=MinioStorage(), null=True, blank=True)
    waypoint = models.ForeignKey(Waypoint, on_delete=models.CASCADE, related_name='media_items')
    
@receiver(post_save, sender=WaypointViewImage)
def sync_test_train_images(sender, instance, created, **kwargs):
    if not instance.image:
        return

    storage = MinioStorage()
    tour_id = instance.waypoint_view.waypoint.tour.pk

    all_images = WaypointViewImage.objects.filter(waypoint_view__waypoint__tour__pk=tour_id)
    image_count = all_images.count()

    for image in all_images:
        path = image.image.name
        if "/test/" in image.image.name:
            if image_count < 5:
                train_path = path.replace("/test/", "/train/")
                if not storage.exists(train_path):
                    content = storage.open(path).read()
                    storage.save(train_path, ContentFile(content))
            else:
                train_path = path.replace("/test/", "/train/")
                if storage.exists(train_path):
                    storage.delete(train_path)
