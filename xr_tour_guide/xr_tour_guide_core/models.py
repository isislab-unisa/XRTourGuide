from django.db import models
from location_field.models.plain import PlainLocationField
import dotenv
from storages.backends.s3boto3 import S3Boto3Storage
from django.core.files.base import ContentFile
import os
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AbstractUser
from django.db import models

dotenv.load_dotenv()

def upload_to(instance, file_name):
    poi_id = instance.waypoint.tour.id
    return f"{poi_id}/{instance.waypoint.id}/data/img/{file_name}"

def upload_media_item(instance, filename):
    field_name = None
    for f in instance._meta.fields:
        if hasattr(instance, f.name) and getattr(instance, f.name, None):
            if hasattr(getattr(instance, f.name), 'name') and getattr(instance, f.name).name == filename:
                field_name = f.name
                break

    poi_id = instance.tour.id
    subfolder = {
        'pdf_item': 'pdf',
        'readme_item': 'readme',
        'video_item': 'video',
        'audio_item': 'audio',
        # 'text_item': 'text',
    }.get(field_name, 'other')

    return f"{poi_id}/{instance.id}/data/{subfolder}/{filename}"

# def default_image_waypoint(instance, file_name):
#     return f"{instance.tour.id}/{instance.id}/default_image/{file_name}"

def default_image_tour(instance, file_name):
    return f"{instance.id}/default_image/{file_name}"

class CustomUser(AbstractUser):
    city = models.CharField(max_length=100, blank=True)
    description = models.TextField(blank=True)
    email = models.EmailField(unique=True)

class MinioStorage(S3Boto3Storage):
    bucket_name = os.getenv("AWS_STORAGE_BUCKET_NAME")
    custom_domain = False
    
# class Tag(models.Model):
#     name = models.CharField(max_length=64, null=False, blank=False, primary_key=True)
    
#     class Meta:
#         db_table = "Tag"
#         verbose_name = "Tag"
#         verbose_name_plural = "Tag"
        
#     def __str__(self):
#         return self.name

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
    MIXED = "MIXED", "Mixed"
        
class TourQuerySet(models.QuerySet):
    def delete(self, *args, **kwargs):
        for obj in self:
            obj.delete()
        super().delete(*args, **kwargs)

class Tour(models.Model):
    title = models.CharField(max_length=200, blank=False, null=False, unique=True)
    subtitle = models.CharField(max_length=200, blank=True, null=True)
    place = models.CharField(max_length=200, blank=False, null=False)
    coordinates = PlainLocationField(zoom=7, null=True, blank=True)
    category = models.CharField(
        max_length=20,
        choices=Category.choices,
        default=Category.INSIDE,
    )
    default_image = models.ImageField(upload_to=default_image_tour, storage=MinioStorage(), null=False, blank=False)
    description = models.TextField(null=True, blank=True)
    objects = TourQuerySet.as_manager()
    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    build_started_at = models.DateTimeField(null=True, blank=True)
    user = models.ForeignKey(get_user_model(), on_delete=models.SET_NULL, null=True, blank=True)
    creation_time = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.READY
    )
    tot_view = models.IntegerField(default=0)
    last_edited = models.DateTimeField(auto_now=True, null=True, blank=True)
    sub_tours = models.ManyToManyField('self', symmetrical=False, blank=True, related_name='parent_tours', null=True)
     
    class Meta:
        db_table = "Tour"
        verbose_name = "Tour"
        verbose_name_plural = "Tours"
                
    def __str__(self):
        return self.title
    
    def get_folder_name(self):
        return f"{self.pk}"
    
    def delete(self, *args, **kwargs):
        for sub_tour in self.sub_tours.all():
            sub_tour.delete()

        folder_name = self.get_folder_name() + "/"
        storage = MinioStorage()
        elements = storage.bucket.objects.filter(Prefix=folder_name)
        try:
            for k in elements:
                k.delete()
        except Exception:
            objects = list(storage.bucket.objects.all())
            object_keys = [obj.key for obj in objects]
            raise Exception(f"La cartella {folder_name} non esiste. Oggetti presenti: {object_keys}")

        super().delete(*args, **kwargs)

    def save(self, *args, **kwargs):
        is_new = self.pk is None

        if is_new:
            super().save(*args, **kwargs)

        if self.default_image and "None" in self.default_image.name:
            storage = MinioStorage()
            old_path = self.default_image.name
            filename = old_path.split("/")[-1]
            new_path = f"{self.pk}/default_image/{filename}"

            if storage.exists(old_path):
                file_content = storage.open(old_path)
                storage.save(f"{self.pk}/default_image/.keep", ContentFile(b""))
                storage.save(new_path, file_content)
                self.default_image.name = new_path
                storage.delete(old_path)
                super().save(update_fields=["default_image"])

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
    description = models.TextField(blank=True, null=True)
    model_path = models.CharField(max_length=200, blank=True, null=True)
    
    # tag = models.ForeignKey(Tag, on_delete=models.SET_NULL, null=True, blank=False)
    timestamp = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    build_started_at = models.DateTimeField(null=True, blank=True)
    # default_image = models.ImageField(upload_to=default_image_waypoint, storage=MinioStorage(), null=True, blank=True)
    
    pdf_item = models.FileField(upload_to=upload_media_item, storage=MinioStorage(), null=True, blank=True)
    readme_item = models.FileField(upload_to=upload_media_item, storage=MinioStorage(), null=True, blank=True)
    video_item = models.FileField(upload_to=upload_media_item, storage=MinioStorage(), null=True, blank=True)
    audio_item = models.FileField(upload_to=upload_media_item, storage=MinioStorage(), null=True, blank=True)
    # text_item = models.FileField(upload_to=upload_media_item, storage=MinioStorage(), null=True, blank=True)
    
    def save(self, *args, **kwargs):
        if self.tour and self.tour.category == Category.INSIDE:
            self.coordinates = self.tour.coordinates
        is_new = self.pk is None
        old_files = {
            # 'default_image': self.default_image,
            'pdf_item': self.pdf_item,
            'readme_item': self.readme_item,
            'video_item': self.video_item,
            'audio_item': self.audio_item,
        }

        super().save(*args, **kwargs)

        if is_new:
            updated_fields = []

            def move_file(field_name, subfolder):
                file_field = old_files[field_name]
                if not file_field:
                    return None
                filename = os.path.basename(file_field.name)
                old_path = file_field.name
                new_path = f"{self.tour.id}/{self.id}/data/{subfolder}/{filename}"
                file = file_field.file
                file.open()
                self._meta.get_field(field_name).storage.save(new_path, file)
                setattr(self, field_name, new_path)
                updated_fields.append(field_name)
                if self._meta.get_field(field_name).storage.exists(old_path):
                    self._meta.get_field(field_name).storage.delete(old_path)

            # if old_files['default_image']:
            #     filename = os.path.basename(old_files['default_image'].name)
            #     old_path = old_files['default_image'].name
            #     new_path = f"{self.tour.id}/{self.id}/default_image/{filename}"
            #     file = old_files['default_image'].file
            #     file.open()
            #     self.default_image.storage.save(new_path, file)
            #     self.default_image = new_path
            #     updated_fields.append('default_image')
            #     if self.default_image.storage.exists(old_path):
            #         self.default_image.storage.delete(old_path)

            move_file('pdf_item', 'pdf')
            move_file('readme_item', 'readme')
            move_file('video_item', 'video')
            move_file('audio_item', 'audio')

            if updated_fields:
                super().save(update_fields=updated_fields)


    class Meta:
        db_table = "Waypoint"
        verbose_name = "Waypoint"
        verbose_name_plural = "Waypoints"

    def __str__(self):
        return self.title

class WaypointLink(models.Model):
    waypoint = models.ForeignKey(Waypoint, related_name='links', on_delete=models.CASCADE)
    title = models.CharField(max_length=200, blank=False, null=False)
    link = models.URLField()
    
class WaypointViewImage(models.Model):
    waypoint = models.ForeignKey(Waypoint, related_name='images', on_delete=models.CASCADE, null=True, blank=True)
    image = models.ImageField(upload_to=upload_to, storage=MinioStorage(), null=True, blank=True)
    
    # def save(self, *args, **kwargs):
    #     is_new = self.pk is None
    #     old_path = f"{self.waypoint.tour.id}/{self.waypoint.id}/None/data/test/{self.waypoint.tag.name.replace(" ", "_")}/"
    #     super().save(*args, **kwargs)

    #     if is_new and self.image and self.waypoint and self.waypoint.id:
    #         poi_id = self.waypoint.tour.id
    #         tag = self.waypoint.tag.name.replace(" ", "_") if self.waypoint.tag else "notag"
    #         filename = os.path.basename(self.image.name)
    #         new_path = f"{poi_id}/{self.waypoint.id}/data/test/{tag}/{filename}"

    #         file = self.image.file
    #         file.open()
    #         self.image.storage.save(new_path, file)
    #         self.image = new_path
    #         super().save(update_fields=["image"])

    #         # if old_path and self.image.storage.exists(old_path):
    #         self.image.storage.delete(old_path)
    
    def __str__(self):
        return f"Image for {self.waypoint.title}"
    
# @receiver(post_save, sender=WaypointViewImage)
# def sync_test_train_images(sender, instance, created, **kwargs):
#     if not instance.image:
#         return

#     storage = MinioStorage()
#     waypoint = instance.waypoint

#     all_images = WaypointViewImage.objects.filter(waypoint=waypoint).exclude(pk=instance.pk)
#     for image in all_images:
#         if "/test/" in image.image.name:
#             storage.delete(image.image.name)
#             image.delete()

#     image_count = WaypointViewImage.objects.filter(waypoint=waypoint).count()

#     path = instance.image.name
#     if "/test/" in path and image_count < 5:
#         train_path = path.replace("/test/", "/train/")
#         if not storage.exists(train_path):
#             content = storage.open(path).read()
#             storage.save(train_path, ContentFile(content))
#             instance.image.name = train_path
#             instance.save()

class Review(models.Model):
    tour = models.ForeignKey(Tour, on_delete=models.CASCADE, related_name='reviews')
    user = models.ForeignKey(get_user_model(), on_delete=models.CASCADE, related_name='reviews')
    rating = models.IntegerField()
    comment = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True)