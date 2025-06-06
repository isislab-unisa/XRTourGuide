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
from .models import MinioStorage, WaypointView, Waypoint, WaypointView

@api_view(['GET'])
def tour_list(request, category):
    searchTerm = request.GET.get('searchTerm', '')
    filters = Q(category__iexact=category)
    if searchTerm:
        filters &=Q(nome__icontains=searchTerm) | Q(sottotitolo__icontains=searchTerm) | Q(descrizione__icontains=searchTerm) | Q(luogo__icontains=searchTerm) | Q(coordinate__icontains=searchTerm)
    tours = Tour.objects.filter(filters)
    serializer = TourSerializer(tours, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
def tour_details(request, pk):
    tour = Tour.objects.get(pk=pk)
    serializer = TourSerializer(tour)
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile_details(request):
    user = request.user
    serializer = UserSerializer(user)
    return Response(serializer.data, status=status.HTTP_200_OK)

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

# @api_view(['POST'])
# @permission_classes([IsAuthenticated])
# def forget_password(request):
#     user = request.user
#     user.set_unusable_password()
#     user.save()
#     return Response({"detail": "Password removed. Reset necessary via email."}, status=status.HTTP_200_OK)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_account(request):
    user = request.user
    password = request.data.get('password')

    if not user.check_password(password):
        return Response({"detail": "Password is incorrect."}, status=status.HTTP_400_BAD_REQUEST)

    user.delete()
    return Response({"detail": "Account deleted successfully."}, status=status.HTTP_200_OK)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def stream_minio_resource(request, waypoint_id):
    file_name = request.GET.get("file")

    if not file_name:
        return Response({"detail": "File name non fornito"}, status=400)

    try:
        waypoint = WaypointView.objects.get(id=waypoint_id)
    except WaypointView.DoesNotExist:
        return Response({"detail": "Waypoint non trovato"}, status=404) 
    
    file_path = f"{waypoint_id}/data/media/{file_name}"
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