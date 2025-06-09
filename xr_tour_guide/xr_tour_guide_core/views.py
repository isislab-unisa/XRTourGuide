from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status
from .models import Tour
from .serializers import TourSerializer
from django.db.models import Q
from .serializers import UserSerializer
from rest_framework.permissions import IsAuthenticated
from django.http import StreamingHttpResponse, Http404, FileResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from storages.backends.s3boto3 import S3Boto3Storage
import mimetypes
from .models import MinioStorage, Waypoint
from rest_framework.permissions import AllowAny
from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi

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
def tour_list(request, category):
    searchTerm = request.GET.get('searchTerm', '')
    filters = Q(category__iexact=category)
    if searchTerm:
        filters &=Q(title__icontains=searchTerm) | Q(description__icontains=searchTerm) | Q(place__icontains=searchTerm) | Q(coordinates__icontains=searchTerm)
    try:
        tours = Tour.objects.filter(filters)
    except Tour.DoesNotExist:
        return Response(status=status.HTTP_404_NOT_FOUND)
    serializer = TourSerializer(tours, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

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

    if first_name:
        user.first_name = first_name
    if last_name:
        user.last_name = last_name
    if email:
        user.email = email

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
def stream_minio_resource(request, waypoint_id):
    file_name = request.GET.get("file")

    if not file_name:
        return Response({"detail": "File name non fornito"}, status=400)

    try:
        waypoint = Waypoint.objects.get(id=waypoint_id)
    except Waypoint.DoesNotExist:
        return Response({"detail": "Waypoint non trovato"}, status=404) 
    
    if waypoint.pdf_item.name == file_name:
        file_path = f"{waypoint.tour.id}/{waypoint_id}/data/pdf/{file_name}"
    elif waypoint.audio_item.name == file_name:
        file_path = f"{waypoint.tour.id}/{waypoint_id}/data/audio/{file_name}"
    elif waypoint.video_item.name == file_name:
        file_path = f"{waypoint.tour.id}/{waypoint_id}/data/video/{file_name}"
    elif waypoint.readme_item.name == file_name:
        file_path = f"{waypoint.tour.id}/{waypoint_id}/data/readme/{file_name}"
    elif waypoint.default_image.name == file_name:
        file_path = f"{waypoint.tour.id}/{waypoint_id}/default_image/{file_name}"
    else:
        return Response({"detail": "File non trovato"}, status=404)
    
    storage = MinioStorage()

    if not storage.exists(file_path):
        return Response({"detail": "File non trovato"}, status=404)

    file = storage.open(file_path, mode='rb')

    content_type, _ = mimetypes.guess_type(file_name)
    if content_type is None:
        content_type = 'application/octet-stream'

    response = FileResponse(file, as_attachment=False, filename=file_name)
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
def get_reviews(request, tour_id):
    try:
        reviews = Tour.objects.get(id=tour_id).reviews_set.all()
    except:
        return Response({"detail": "Tour non trovato"}, status=status.HTTP_404_NOT_FOUND)
    
    serializer = TourSerializer(reviews, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)
