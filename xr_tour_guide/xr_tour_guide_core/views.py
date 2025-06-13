from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status
from .serializers import TourSerializer, WaypointSerializer, ReviewSerializer, WaypointViewImageSerializer
from django.db.models import Q
from .serializers import UserSerializer
from rest_framework.permissions import IsAuthenticated
from django.http import StreamingHttpResponse, Http404, FileResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from storages.backends.s3boto3 import S3Boto3Storage
import mimetypes
from .models import MinioStorage, Waypoint, Tour, Review
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
    filters = Q()
    if category:
        filters &= Q(category__iexact=category)
    if searchTerm:
        filters &= (
            Q(title__icontains=searchTerm) | 
            Q(place__icontains=searchTerm)
        )
    tours = Tour.objects.filter(filters) or Tour.objects.all()
    serializer = TourSerializer(tours, many=True)
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
    except Tour.DoesNotExist:
        return Response({"detail": "Tour non trovato"}, status=status.HTTP_404_NOT_FOUND)
    serializer = WaypointSerializer(waypoints, many=True)
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
    elif "test" or "train" in file_name:
        file_path = file_name
    else:
        return Response({"detail": "File non rovato"}, status=404)
    
    storage = MinioStorage()

    if not storage.exists(file_path):
        return Response({"detail": f"File {file_name} non trovato"}, status=404)

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
def get_reviews_by_tour_id(request, tour_id):
    try:
        reviews = Tour.objects.get(id=tour_id).reviews_set.all()
    except:
        return Response({"detail": "Tour non trovato"}, status=status.HTTP_404_NOT_FOUND)
    
    serializer = TourSerializer(reviews, many=True)
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
    method='post',
    operation_summary="Increment the view count for a specific tour",
    responses={
        200: openapi.Response(description="View count incremented successfully"),
        404: openapi.Response(description="Tour not found"),
    }
)
def increment_view_count(request, tour_id):
    try:
        tour = Tour.objects.get(id=tour_id)
    except Tour.DoesNotExist:
        return Response({"detail": "Tour not found"}, status=status.HTTP_404_NOT_FOUND)

    tour.view_count += 1
    tour.save()

    return Response({"detail": "View count incremented successfully"}, status=status.HTTP_200_OK)