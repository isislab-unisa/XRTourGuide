from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status
from ..serializers import ReviewSerializer
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from ..models import Tour, Review
from rest_framework.permissions import AllowAny
from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi
from rest_framework import status
from rest_framework.response import Response

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
