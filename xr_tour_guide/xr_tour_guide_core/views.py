import os
import sys
# sys.path.append(os.path.join(os.path.dirname(__file__), 'inference'))

from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status
from .serializers import TourSerializer, WaypointSerializer, ReviewSerializer, WaypointViewImageSerializer, PasswordResetSerializer, PasswordResetConfirmSerializer
from django.db.models import Q
from .serializers import UserSerializer
from rest_framework.permissions import IsAuthenticated
from django.http import HttpResponse, JsonResponse, StreamingHttpResponse, Http404, FileResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
import mimetypes
from .models import MinioStorage, Waypoint, Tour, Review, Category, WaypointViewImage
from rest_framework.permissions import AllowAny
from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi
from rest_framework import generics, status
from rest_framework.response import Response
from django.urls import reverse
from django.core.mail import send_mail
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_decode
from django.shortcuts import get_object_or_404
from rest_framework.views import APIView
from .serializers import RegisterSerializer
from django.contrib.auth import get_user_model
from django.shortcuts import render, redirect
from django.views import View
from xr_tour_guide.tasks import call_api_and_save
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_http_methods
import requests
import redis
from redis.lock import Lock
import subprocess
import tempfile
from django.conf import settings

redis_client = redis.StrictRedis.from_url(os.getenv("REDIS_URL", "redis://redis:6379"))

@swagger_auto_schema(
    method='get',
    operation_summary="List tours by category with optional search term",
    manual_parameters=[
        openapi.Parameter(
            'searchTerm', openapi.IN_QUERY, 
            description="Keyword to search in title, description, place or coordinates", 
            type=openapi.TYPE_STRING
        )
    ],
    responses={200: TourSerializer(many=True)}
)
@api_view(['GET'])
@permission_classes([AllowAny])
def tour_list(request):
    searchTerm = request.GET.get('searchTerm', '')
    category = request.GET.get('category', '')

    queryset = Tour.objects.filter(parent_tours__isnull=True, is_subtour=False)

    if category:
        queryset = queryset.filter(category__iexact=category)
    if searchTerm:
        queryset = queryset.filter(
            Q(title__icontains=searchTerm) |
            Q(place__icontains=searchTerm)
        )

    serializer = TourSerializer(queryset, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@swagger_auto_schema(
    method='get',
    operation_summary="Retrieve details for a specific tour by ID",
    responses={
        200: TourSerializer(),
        404: openapi.Response(description="Tour not found")
    }
)
@api_view(['GET'])
@permission_classes([AllowAny])
def tour_detail(request, tour_id):
    try:
        tour = Tour.objects.get(pk=tour_id)
    except Tour.DoesNotExist:
        return Response({"detail": "Tour non trovato"}, status=status.HTTP_404_NOT_FOUND)
    serializer = TourSerializer(tour)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([AllowAny])
def tour_waypoints(request, tour_id):
    try:
        tour = Tour.objects.get(pk=tour_id)
        waypoints = tour.waypoints.all()
        sub_tour_data = None
        if tour.category == Category.MIXED:
            sub_tour = tour.sub_tours.all()
            sub_tour_data = []
            for st in sub_tour:
                st_waypoints = st.waypoints.all()
                st_serializer = WaypointSerializer(st_waypoints, many=True)
                st_data = {
                    'sub_tour': TourSerializer(st).data,
                    'waypoints': st_serializer.data
                }
                sub_tour_data.append(st_data)
    except Tour.DoesNotExist:
        return Response({"detail": "Tour non trovato"}, status=status.HTTP_404_NOT_FOUND)
    serializer = WaypointSerializer(waypoints, many=True)
    data = {
        'waypoints': serializer.data,
        'sub_tours': sub_tour_data
    }
    return Response(data, status=status.HTTP_200_OK)


@swagger_auto_schema(
    method='get',
    operation_summary="Retrieve details for a specific tour",
    responses={
        200: TourSerializer(),
        404: openapi.Response(description="Tour not found")
    }
)
@api_view(['GET'])
@permission_classes([AllowAny])
def tour_details(request, pk):
    try:
        tour = Tour.objects.get(pk=pk)
    except Tour.DoesNotExist:
        return Response({"detail": "Tour non trovato"}, status=status.HTTP_404_NOT_FOUND)
    serializer = TourSerializer(tour)
    return Response(serializer.data, status=status.HTTP_200_OK)

@swagger_auto_schema(
    method='get',
    operation_summary="Retrieve the current authenticated user's profile",
    responses={200: UserSerializer()}
)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile_details(request):
    user = request.user
    serializer = UserSerializer(user)
    return Response(serializer.data, status=status.HTTP_200_OK)

@swagger_auto_schema(
    method='post',
    operation_summary="Update the current authenticated user's profile",
    request_body=openapi.Schema(
        type=openapi.TYPE_OBJECT,
        properties={
            'firstName': openapi.Schema(type=openapi.TYPE_STRING),
            'lastName': openapi.Schema(type=openapi.TYPE_STRING),
            'email': openapi.Schema(type=openapi.TYPE_STRING, format='email'),
            'description': openapi.Schema(type=openapi.TYPE_STRING),
        }
    ),
    responses={200: openapi.Response(description="Profile updated successfully")}
)
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_profile(request):
    user = request.user
    first_name = request.data.get('firstName', '').strip()
    last_name = request.data.get('lastName', '').strip()
    email = request.data.get('email', '').strip()
    description = request.data.get('description', '').strip()

    if first_name:
        user.first_name = first_name
    if last_name:
        user.last_name = last_name
    if email:
        user.email = email
    if user.description == description:
        user.description = description

    user.save()
    return Response({"detail": "Profile updated successfully."}, status=status.HTTP_200_OK)

@swagger_auto_schema(
    method='post',
    operation_summary="Update the user's password",
    request_body=openapi.Schema(
        type=openapi.TYPE_OBJECT,
        required=['oldPassword', 'newPassword'],
        properties={
            'oldPassword': openapi.Schema(type=openapi.TYPE_STRING),
            'newPassword': openapi.Schema(type=openapi.TYPE_STRING),
        }
    ),
    responses={
        200: openapi.Response(description="Password updated successfully"),
        400: openapi.Response(description="Old password is incorrect")
    }
)
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_password(request):
    user = request.user
    old_password = request.data.get('oldPassword')
    new_password = request.data.get('newPassword')

    if not user.check_password(old_password):
        return Response({"detail": "Old password is incorrect."}, status=status.HTTP_400_BAD_REQUEST)

    user.set_password(new_password)
    user.save()
    return Response({"detail": "Password updated successfully."}, status=status.HTTP_200_OK)

@swagger_auto_schema(
    method='post',
    operation_summary="Delete the current user's account",
    request_body=openapi.Schema(
        type=openapi.TYPE_OBJECT,
        required=['password'],
        properties={
            'password': openapi.Schema(type=openapi.TYPE_STRING)
        }
    ),
    responses={
        200: openapi.Response(description="Account deleted successfully"),
        400: openapi.Response(description="Password is incorrect")
    }
)
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_account(request):
    user = request.user
    password = request.data.get('password')

    if not user.check_password(password):
        return Response({"detail": "Password is incorrect."}, status=status.HTTP_400_BAD_REQUEST)

    user.delete()
    return Response({"detail": "Account deleted successfully."}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def forgot_password(request):
    return Response({"detail": "Password reset email sent successfully."}, status=status.HTTP_200_OK)

@swagger_auto_schema(
    method='get',
    operation_summary="Stream a specific file from MinIO storage for a waypoint",
    manual_parameters=[
        openapi.Parameter(
            'file', openapi.IN_QUERY, 
            description="Exact name of the file to stream (pdf/audio/video/readme/image)", 
            type=openapi.TYPE_STRING,
            required=True
        )
    ],
    responses={
        200: openapi.Response(description="File streamed successfully"),
        400: openapi.Response(description="File name not provided"),
        404: openapi.Response(description="Waypoint or file not found")
    }
)
@api_view(['GET'])
@permission_classes([AllowAny]) 
def stream_minio_resource(request):
    storage = MinioStorage()
    tour_id = request.GET.get("tour")
    waypoint_id = request.GET.get("waypoint")
    file_name = request.GET.get("file")
    attachment = request.GET.get("attachment")

    try:
        if tour_id and waypoint_id is None:
            tour = Tour.objects.get(id=tour_id)
            file = storage.open(tour.default_image.name, mode='rb')
            content_type, _ = mimetypes.guess_type(tour.default_image.name)
            if content_type is None:
                content_type = 'application/octet-stream'

            response = FileResponse(file, as_attachment=False, filename=file_name)
            response['Content-Type'] = content_type
            return response
    except Exception as e:
        return Response({"detail": tour.default_image.name}, status=404)
    
    if not file_name:
        return Response({"detail": "File name non fornito"}, status=400)
        
    try:
        waypoint = Waypoint.objects.get(id=waypoint_id)
    except Waypoint.DoesNotExist:
        return Response({"detail": "Waypoint non trovato"}, status=404) 
    
    if "pdf" == file_name:
        file_path = waypoint.pdf_item.name
    elif "audio" == file_name:
        file_path = waypoint.audio_item.name
    elif "video" == file_name:
        file_path = waypoint.video_item.name
    elif "readme" == file_name:
        file_path = waypoint.readme_item.name
    elif "img" in file_name:
        file_path = file_name
    else:
        return Response({"detail": "File non rovato"}, status=404)

    if not storage.exists(file_path):
        return Response({"detail": f"File {file_name}, {waypoint.pdf_item.name}, {file_path} non trovato"}, status=404)

    file = storage.open(file_path, mode='rb')

    content_type, _ = mimetypes.guess_type(file_path)
    if content_type is None:
        content_type = 'application/octet-stream'

    response = FileResponse(file, as_attachment=True if attachment else False, filename=file_name)
    response['Content-Type'] = content_type
    return response

@swagger_auto_schema(
    method='get',
    operation_summary="Retrieve reviews for a specific tour",
    responses={
        200: openapi.Response(description="List of reviews (serialized)"),
        404: openapi.Response(description="Tour not found")
    }
)
@api_view(['GET'])
@permission_classes([AllowAny])
def get_reviews_by_tour_id(request, tour_id):
    try:
        tour = Tour.objects.get(id=tour_id)
    except:
        return Response({"detail": "Tour non trovato"}, status=status.HTTP_404_NOT_FOUND)
    
    reviews = tour.reviews.all()
    
    serializer = ReviewSerializer(reviews, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

class RegisterView(generics.CreateAPIView):
    queryset = get_user_model().objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]

    def perform_create(self, serializer):
        user = serializer.save()
        token = default_token_generator.make_token(user)
        uid = urlsafe_base64_encode(force_bytes(user.pk))
        activation_link = self.request.build_absolute_uri(
            reverse('activate-account', kwargs={'uidb64': uid, 'token': token})
        )
        send_mail(
            subject='Activate your account',
            message=f'Click here to activate the account: {activation_link}',
            from_email=None,
            recipient_list=[user.email]
        )

class ActivateAccountView(APIView):
    permission_classes = [AllowAny]
    def get(self, request, uidb64, token):
        try:
            uid = urlsafe_base64_decode(uidb64).decode()
            user = get_object_or_404(get_user_model(), pk=uid)
        except (TypeError, ValueError, OverflowError, get_user_model().DoesNotExist):
            return Response({'error': 'Link non valido'}, status=400)

        if default_token_generator.check_token(user, token):
            user.is_active = True
            user.save()
            return Response({'message': 'Account attivato correttamente'}, status=200)
        return Response({'error': 'Token non valido'}, status=400)

@swagger_auto_schema(
    method='post',
    operation_summary="Create a new review for a specific tour",
    request_body=openapi.Schema(
        type=openapi.TYPE_OBJECT,
        required=['tour_id', 'rating', 'comment'],
        properties={
            'tour_id': openapi.Schema(type=openapi.TYPE_INTEGER, description='ID of the tour'),
            'rating': openapi.Schema(type=openapi.TYPE_NUMBER, format='float', description='Rating for the tour'),
            'comment': openapi.Schema(type=openapi.TYPE_STRING, description='Review comment'),
        },
    ),
    responses={
        201: openapi.Response(description="Review created successfully"),
        404: openapi.Response(description="Tour not found"),
    }
)
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_review(request):
    tour_id = request.data.get('tour_id')
    rating = request.data.get('rating')
    review_text = request.data.get('comment')

    try:
        tour = Tour.objects.get(id=tour_id)
    except Tour.DoesNotExist:
        return Response({"detail": "Tour not found"}, status=status.HTTP_404_NOT_FOUND)

    review = Review.objects.create(tour=tour, user=request.user, rating=rating, comment=review_text)
    return Response({"detail": "Review created successfully"}, status=status.HTTP_201_CREATED)

@swagger_auto_schema(
    method='get',
    operation_summary="Retrieve all reviews made by the currently logged in user",
    responses={
        200: openapi.Response(description="List of reviews (serialized)"),
    }
)
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_reviews_by_user(request):
    reviews = Review.objects.filter(user=request.user)
    serializer = ReviewSerializer(reviews, many=True)
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([AllowAny])
@swagger_auto_schema(
    operation_summary="Increment the view count for a specific tour",
    responses={200: openapi.Response(description="Tour updated successfully")}
)
def increment_view_count(request):
    tour_id = request.data.get('tour_id')
    try:
        tour = Tour.objects.get(id=tour_id)
    except Tour.DoesNotExist:
        return Response({"detail": "Tour not found"}, status=status.HTTP_404_NOT_FOUND)

    tour.tot_view += 1
    tour.save()

    return Response({"detail": "View count incremented successfully"}, status=status.HTTP_200_OK)

@permission_classes([AllowAny])
class PasswordResetView(generics.GenericAPIView):
    serializer_class = PasswordResetSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response({"detail": "Email sent with instructions to reset the password."})

@permission_classes([AllowAny])
class PasswordResetConfirmView(generics.GenericAPIView):
    serializer_class = PasswordResetConfirmSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response({"detail": "Password updated successfully."})

class PasswordResetConfirmPage(View):
    def get(self, request, uidb64, token):
        context = {'uidb64': uidb64, 'token': token}
        return render(request, 'password_reset_confirm.html', context)

class PasswordResetConfirmSubmit(View):
    def post(self, request, uidb64, token):
        new_password = request.POST.get('new_password')
        try:
            uid = urlsafe_base64_decode(uidb64).decode()
            user = get_user_model().objects.get(pk=uid)
        except Exception:
            return render(request, 'password_reset_confirm.html', {'error': 'Link non valido', 'uidb64': uidb64, 'token': token})

        if not default_token_generator.check_token(user, token):
            return render(request, 'password_reset_confirm.html', {'error': 'Token scaduto o non valido', 'uidb64': uidb64, 'token': token})

        user.set_password(new_password)
        user.save()
        return redirect('/')

# @permission_classes([AllowAny])
# @api_view(['POST'])
@login_required
@require_http_methods(['POST'])
def build(request):
    tour_id = int(request.POST.get('tour_id'))
    try:
        tour = Tour.objects.get(pk=tour_id)
    except Tour.DoesNotExist as e:
        print(f"This tour: {tour_id} does not exist")
    if tour.status == "READY":
        tour.status = "ENQUEUED"
        tour.save()
        call_api_and_save.apply_async(args=[tour.id], queue='api_tasks')
    else:
        return JsonResponse({"message": "Tour already built"}, status=400)
    return redirect('/admin/')

@api_view(['POST'])
def complete_build(request):
    allowed_ip = "172.28.0.20"
    remote_ip = request.META.get("REMOTE_ADDR")

    if remote_ip != allowed_ip:
        return JsonResponse({"error": "Access denied"}, status=403)

    print(f"Request data: {request.POST.get('poi_id')}")
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
def get_waypoint_resources(request):
    waypoint_id = request.GET.get('waypoint_id')
    resource_type = request.GET.get('resource_type')

    try:
        waypoint = Waypoint.objects.get(id=waypoint_id)
    except Waypoint.DoesNotExist:
        return JsonResponse({"error": "Waypoint not found"}, status=404)

    if resource_type == "readme" and waypoint.readme_item:
        try:
            storage = MinioStorage()
            file_content = storage.open(waypoint.readme_item.name, mode='r').read()
            return JsonResponse({"readme": file_content}, status=200)
        except Exception as e:
            return JsonResponse({"url": f"/stream_minio_resource?waypoint={waypoint_id}&file=readme"}, status=200)
    elif resource_type == "video" and waypoint.video_item:
        return JsonResponse({"url": f"/stream_minio_resource?waypoint={waypoint_id}&file=video"}, status=200)

    elif resource_type == "audio" and waypoint.audio_item:
        return JsonResponse({"url": f"/stream_minio_resource?waypoint={waypoint_id}&file=audio"}, status=200)

    elif resource_type == "pdf" and waypoint.pdf_item:
        return JsonResponse({"url": f"/stream_minio_resource?waypoint={waypoint_id}&file=pdf"}, status=200)
    # elif resource_type == "links" and waypoint.links.exists():
    #     links = waypoint.links.all()
    #     readme_content = "\n".join([f"[{link.title}]: {link.link}" for link in links])
    #     return JsonResponse({"readme": readme_content}, status=200)

    elif resource_type == "images":
        images = waypoint.images.all()[:10]
        if not images.exists():
            return JsonResponse({"error": "No images found"}, status=404)

        readme_content = "\n".join(
            [f"![{i+1}](/stream_minio_resource/?waypoint={waypoint_id}&file={img.image.name})" for i, img in enumerate(images)]
        )
        return JsonResponse({"readme": readme_content}, status=200)

    else:
        return JsonResponse({"error": "Invalid resource type"}, status=400)

@api_view(['GET'])
@permission_classes([AllowAny])
def download_model(request):
    storage = MinioStorage()

    tour_id = request.GET.get('tour_id')
    model = storage.open(f"/{tour_id}/training_data.json", mode='r').read()

    return HttpResponse(model, content_type='application/json')

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cut_map(request, tour_id):
    storage = MinioStorage()

    try:
        tour = Tour.objects.get(pk=tour_id)
    except Tour.DoesNotExist:
        return JsonResponse({"error": "Tour not found"}, status=404)

    if storage.exists(f"{tour_id}/tour_{tour_id}.pmtiles"):
        file = storage.open(f"/{tour_id}/tour_{tour_id}.pmtiles", mode='rb')
        return FileResponse(file, as_attachment=True, filename=f"tour_{tour_id}.pmtiles")
    
    waypoints = tour.waypoints.all()
    if not waypoints.exists():
        return JsonResponse({"error": "No waypoints found for this tour"}, status=400)

    lons, lats = [], []
    for wp in waypoints:
        try:
            lat_str, lon_str = wp.coordinates.split(",")
            lat, lon = float(lat_str.strip()), float(lon_str.strip())
            lats.append(lat)
            lons.append(lon)
        except Exception:
            continue

    if not lats or not lons:
        return JsonResponse({"error": "Waypoints have invalid coordinates"}, status=400)

    min_lon, max_lon = min(lons), max(lons)
    min_lat, max_lat = min(lats), max(lats)
    bbox = f"{min_lon},{min_lat},{max_lon},{max_lat}"

    payload = {
        "tour_id": str(tour_id),
        "bbox": bbox
    }
    url = "http://pmtiles-server:8081/extract"
    headers = {"Content-type": "application/json"}
    response = requests.post(url, headers=headers, json=payload)
    print("DIOCANE", response, flush=True)
    if response.status_code != 200:
        return JsonResponse({"error": "Failed to extract pmtiles"}, status=400)
    
    file = storage.open(f"/{tour_id}/tour_{tour_id}.pmtiles", mode='rb')
    return FileResponse(file, as_attachment=True, filename=f"tour_{tour_id}.pmtiles")