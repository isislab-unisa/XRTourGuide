import os
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.http import HttpResponse, JsonResponse, FileResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from ..models import MinioStorage, Tour
from rest_framework.permissions import AllowAny
from django.core.mail import send_mail
from django.shortcuts import redirect
from xr_tour_guide.tasks import call_api_and_save
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_http_methods
import requests
import redis

redis_client = redis.StrictRedis.from_url(os.getenv("REDIS_URL", "redis://redis:6379"))

@login_required
@require_http_methods(['POST'])
def build(request):
    tour_id = int(request.POST.get('tour_id'))
    try:
        tour = Tour.objects.get(pk=tour_id)
    except Tour.DoesNotExist as e:
        print(f"This tour: {tour_id} does not exist")
    
    if tour.user != request.user:
        return JsonResponse({"message": "You are not authorized to build this tour"}, status=403)
    
    if tour.status == "READY":
        tour.status = "ENQUEUED"
        tour.save()
        call_api_and_save.apply_async(args=[tour.id], queue='api_tasks')
    else:
        return JsonResponse({"message": "Tour already built"}, status=400)
    return redirect('/admin/')

@api_view(['POST'])
@permission_classes([AllowAny])
def complete_build(request):
    allowed_ip = "172.28.0.20"
    remote_ip = request.META.get("REMOTE_ADDR")

    if remote_ip != allowed_ip:
        return JsonResponse({"error": "Access denied"}, status=403)

    storage = MinioStorage()
    tour_title = request.data.get('poi_name')
    tour_id = request.data.get('poi_id')
    model_url = request.data.get('model_url')
    status = request.data.get('status')

    redis_client = redis.StrictRedis.from_url(os.getenv("REDIS_URL", "redis://redis:6379"))

    if status == "COMPLETED":
        try:
            tour = Tour.objects.get(pk=int(tour_id))
            tour.model_path = model_url
            tour.status = "BUILT"
            tour.save()
        except Tour.DoesNotExist:
            return JsonResponse({"error": "Cromo POI not found"}, status=404)
        except Exception as e:
            return JsonResponse({"error": f"Error saving Cromo POI: {str(e)}"}, status=500)

        send_mail(
            'Build completata',
            f"Lezione {tour.title} buildata.",
            os.environ.get('EMAIL_HOST_USER'),
            [tour.user.email],
            fail_silently=False,
        )

        try:
            redis_client.delete("build_lock")
        except Exception as e:
            print(f"Errore nell'eliminazione del lock: {e}")

        return JsonResponse({"message": "Build completata"}, status=200)

    else:
        tour = Tour.objects.get(pk=tour_id)
        tour.status = "FAILED"
        tour.save()

        send_mail(
            'Build fallita',
            f"Build Fallita {tour.title}.",
            os.environ.get('EMAIL_HOST_USER'),
            [tour.user.email],
            fail_silently=False,
        )

        prefix = f"{tour_id}/data/"
        objects_to_delete = storage.bucket.objects.filter(Prefix=prefix)
        len(objects_to_delete, flush=True)
        for obj in objects_to_delete:
            obj.delete()

        try:
            redis_client.delete("build_lock")
        except Exception as e:
            print(f"Errore nell'eliminazione del lock: {e}")

        return JsonResponse({"error": "Cromo POI not found"}, status=404)

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def load_model(request, tour_id):
    try:
        tour = Tour.objects.get(pk=tour_id)
    except Tour.DoesNotExist:
        return JsonResponse({"error": "Cromo POI not found"}, status=404)
    storage = MinioStorage()
    if storage.exists(
        f"{tour_id}/model.pt"
    ):
        model_file = storage.open(f"/{tour_id}/model.pt")
        os.makedirs("models", exist_ok=True)
        with open(f"models/model_{tour_id}.pt", "wb") as f:
            for chunk in model_file.chunks():
                f.write(chunk)
    else:
        return JsonResponse({"error": "Model not found"}, status=404)
    return JsonResponse({"message": "Model loaded"}, status=200)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def inference(request):
    tour_id = request.data.get('tour_id')
    try:
        tour = Tour.objects.get(pk=tour_id)
    except Tour.DoesNotExist:
        return JsonResponse({"error": "Cromo POI not found"}, status=404)

    payload = {
        "poi_id": str(tour_id),
        "inference_image": request.data.get('img'),
        "model_url": f"{tour.pk}/model.pt",
        "poi_name": tour.title,
    }
    url = "http://ai_inference:8050/inference"
    headers = {"Content-type": "application/json"}
    response = requests.post(url, headers=headers, json=payload)

    result = response.json()
    print(f"RESPONSE: {result.get("message")}", flush=True)

    print("INFERENCE DONE", flush=True)
    
    
    if result is None:
        response_data = {
            "result": -1,
            "available_resources": {
                "pdf": 0,
                "readme": 0,
                "video": 0,
                "audio": 0,
                "links": 0,
            }
        }
        return JsonResponse(response_data, status=200)
    
    waypoint = tour.waypoints.filter(title=result.get("message")).first()

    
    if waypoint is None:
        for sub_tour in tour.sub_tours.all():
            waypoint = sub_tour.waypoints.filter(title=result.get("message")).first()
            if waypoint:
                break

    if waypoint is None:
        print("Waypoint non trovato", flush=True)
        return JsonResponse({
            "result": -1,
            "message": "Waypoint not found in waypoints or in sub-tours",
            "available_resources": {
                "pdf": 0,
                "readme": 0,
                "video": 0,
                "audio": 0,
                "links": 0,
            }
        }, status=200)

    available_resources = {
        "pdf": int(bool(waypoint.pdf_item and waypoint.pdf_item.name)),
        "readme": int(bool(waypoint.readme_item and waypoint.readme_item.name)),
        "video": int(bool(waypoint.video_item and waypoint.video_item.name)),
        "audio": int(bool(waypoint.audio_item and waypoint.audio_item.name)),
        # "links": waypoint.links.exists()
    }

    return JsonResponse({
        "result": waypoint.id,
        "available_resources": available_resources
    }, status=200)

@api_view(['GET'])
@permission_classes([AllowAny])
def download_model(request):
    storage = MinioStorage()

    tour_id = request.GET.get('tour_id')
    model = storage.open(f"/{tour_id}/training_data.json", mode='r').read()

    return HttpResponse(model, content_type='application/json')