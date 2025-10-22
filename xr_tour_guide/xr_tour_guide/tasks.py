import shutil
import requests
from celery import shared_task
from xr_tour_guide_core.models import Tour, MinioStorage, Status, CustomUser
from django.core.mail import send_mail
import os
import json
import time
import redis
from redis.exceptions import LockError
from redis.lock import Lock
from dotenv import load_dotenv
from django.utils import timezone
from datetime import timedelta
from django.core.files.base import ContentFile
from django.contrib.auth import get_user_model

load_dotenv()

redis_client = redis.StrictRedis.from_url(os.getenv("REDIS_URL", "redis://redis:6379"))

@shared_task(bind=True, max_retries=20, default_retry_delay=10)
def call_api_and_save(self, tour_id):
    storage = MinioStorage()
    response = None
    lock = Lock(redis_client, "build_lock", timeout=24 * 60 * 60)

    try:
        tour = Tour.objects.get(pk=tour_id)
        print("Tour:", tour.pk, tour.title)

        print("Tentativo di acquisizione lock...")
        try:
            acquired = lock.acquire(blocking=True, blocking_timeout=24 * 60 * 60)
            print(f"Acquired: {acquired}")
            if not acquired:
                print(f"Could not acquire lock for tour {tour}, retrying...")
                raise self.retry(exc=Exception("Could not acquire build lock"), countdown=10)
        except Exception as lock_error:
            print(f"Errore nell'acquisizione del lock: {lock_error}")
            raise self.retry(exc=lock_error, countdown=10)
        
        print("Lock acquisito, procedo con la build...")
        try:
            storage = MinioStorage()
            if not storage.exists(f"{tour.pk}/data/"):
                storage.save(f"{tour.pk}/data/train/.keep", ContentFile(b""))
                storage.save(f"{tour.pk}/data/test/.keep", ContentFile(b""))
                
            for subtours in tour.sub_tours.all():
                waipoints = subtours.waypoints.all()
                for waypoint in waipoints:
                    num_img = len(waypoint.images.all())
                    if num_img < 5:
                        for i, image in enumerate(waypoint.images.all()):
                            storage.save(f"{tour.pk}/data/train/{waypoint.title}/{image.image.name.split('/')[-1]}", image.image)
                            if i == 1:
                                storage.save(f"{tour.pk}/data/test/{waypoint.title}/{image.image.name.split('/')[-1]}", image.image)
                    else:
                        train = int(num_img * 0.8)
                        test = num_img - train
                        for image in waypoint.images.all()[:train]:
                            storage.save(f"{tour.pk}/data/train/{waypoint.title}/{image.image.name.split('/')[-1]}", image.image)
                        for image in waypoint.images.all()[train:]:
                            storage.save(f"{tour.pk}/data/test/{waypoint.title}/{image.image.name.split('/')[-1]}", image.image)
                            
            waypoints = tour.waypoints.all()
            for waypoint in waypoints:
                images = waypoint.images.all()
                num_img = len(images)
                if num_img < 5:
                    for i, image in enumerate(images):
                        storage.save(f"{tour.pk}/data/train/{waypoint.title}/{image.image.name.split("/")[-1]}", image.image)
                        if i == 1:
                            storage.save(f"{tour.pk}/data/test/{waypoint.title}/{image.image.name.split("/")[-1]}", image.image)
                else:
                    train = int(num_img * 0.8)
                    test = num_img - train
                    for image in images[:train]:
                        storage.save(f"{tour.pk}/data/train/{waypoint.title}/{image.image.name.split("/")[-1]}", image.image)
                    for image in images[train:]:
                        storage.save(f"{tour.pk}/data/test/{waypoint.title}/{image.image.name.split("/")[-1]}", image.image)
                        
        except Exception as e:
            print(f"Errore nella creazione delle cartelle per il train e test: {e}")
        try:
            payload = {
                "poi_name": tour.title,
                "poi_id": str(tour.id),
                "data_url": f"{tour_id}",
            }

            try:
                url = f"http://ai_training:8090/train_model"
                headers = {"Content-type": "application/json"}
                response = requests.post(url, headers=headers, json=payload, verify=False)
            except Exception as e:  
                print(f"Errore nella chiamata API: {e}")
                               
            print("Response status code:", response.status_code)
            print(response)
            
            if response.status_code == 200:
                tour.status = Status.BUILDING
                tour.build_started_at = timezone.now()
                tour.save()
                send_mail(
                    'Build in corso',
                    f"Tour {tour.title} in fase di build.",
                    os.environ.get('EMAIL_HOST_USER'),
                    [tour.user.email],
                    fail_silently=False,
                )
                return f"Tour {tour} in building"
            else:
                status = Status.FAILED
                tour.status = status
                tour.save()
                send_mail(
                    'Build Fallita',
                    f"Tour: {tour.title} fallita. Errore interno del server",
                    os.environ.get('EMAIL_HOST_USER'),
                    [tour.user.email],
                    fail_silently=False,
                )
                if lock.locked():
                    print("Rilascio il lock...")
                    lock.release()
                return f"Build failed for Tour {tour}"  

        except Exception as e:
            print(f"Errore nella chiamata API: {e}")
            if response is not None and response.status_code != 200:
                status = Status.FAILED
                tour.status = status
                tour.save()
                send_mail(
                    'Build Fallita',
                    f"Tour: {tour.title} fallita. Errore interno del server",
                    os.environ.get('EMAIL_HOST_USER'),
                    [tour.user.email],
                    fail_silently=False,
                )
            return str(e)
        finally:
            pass
            # if lock.locked():
            #     print("Rilascio il lock...")
            #     lock.release()

    except Tour.DoesNotExist:
        return f"Tour {tour} does not exist."

    except Exception as e:
        print(f"Errore generale: {e}")
        if response is not None and response.status_code != 200:
            status = Status.FAILED
            tour.status = status
            tour.save()
            send_mail(
                'Build Fallita',
                f"Tour: {tour.title} fallita. Errore interno del server",
                os.environ.get('EMAIL_HOST_USER'),
                [tour.user.email],
                fail_silently=False,
            )
        return str(e)

@shared_task(queue='api_tasks')
def fail_stuck_builds():
    try:
        redis_client = redis.StrictRedis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"))
        build_lock = Lock(redis_client, "build_lock")
    except Exception as e:
        print(f"Errore nell'acquisizione del lock: {e}")
            
    cromo_poi = None
    try:
        timeout_minutes = 10 #18 * 60 # 18 hours
        threshold = timezone.now() - timedelta(minutes=timeout_minutes)

        cromo_poi = Tour.objects.filter(status=Status.BUILDING, build_started_at__lt=threshold).first()
    except Tour.DoesNotExist:
        print("Tour does not exist")
    except Exception as e:
        print(f"Errore: {e}")
        
    if cromo_poi is None:
        return
    try:
        cromo_poi.status = Status.FAILED
        cromo_poi.save()
        send_mail(
            'Build Fallita',
            f"Tour: {cromo_poi.title} è fallita automaticamente per superamento del tempo massimo di build.",
            os.environ.get('EMAIL_HOST_USER'),
            [cromo_poi.user.email],
            fail_silently=False,
        )
    except Exception as e:
        print(f"Errore nell'acquisizione del lock: {e}")
    
    try:
        if build_lock.locked():
            build_lock.release()
    except Exception as e:
        print(f"Errore nell'acquisizione del lock: {e}")

@shared_task(queue='api_tasks')
def remove_append_user():
    try:
        one_minute_ago = timezone.now() - timedelta(minutes=30)
        User = get_user_model()
        users = User.objects.filter(date_joined__lt=one_minute_ago, is_active=False)
        count, _ = users.delete()
        print(f"{count} utenti eliminati", flush=True)
    except Exception as e:
        print(f"Errore nella cancellazione degli utenti: {e}", flush=True)

@shared_task(queue='api_tasks')
def remove_sub_tours():
    difference = timezone.now() - timedelta(hours=5)
    tours = Tour.objects.filter(is_subtour=True, parent_tours__isnull=True, created_at__lt=difference)
    for tour in tours:
        tour.delete()
