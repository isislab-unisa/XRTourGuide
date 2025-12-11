from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status
from ..serializers import TourSerializer, WaypointSerializer
from django.db.models import Q
from rest_framework.permissions import IsAuthenticated
from django.http import JsonResponse, FileResponse
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
import mimetypes
from ..models import MinioStorage, Tour, Category
from rest_framework.permissions import AllowAny
from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi
from rest_framework import status
from rest_framework.response import Response
import requests
import math
from django.db.models import Case, When


def distance(x1, x2, y1, y2):
    return math.sqrt((x1 - y1)**2 + (x2 - y2)**2)

def parse_coordinates(coord_str):
    try:
        lat_str, lon_str = coord_str.split(',')
        return float(lat_str.strip()), float(lon_str.strip())
    except Exception:
        return None, None
    
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
    search_term = request.GET.get('searchTerm', '')
    category = request.GET.get('category', '')
    sort_param = request.GET.get('sorted', '').lower()
    num_tours = request.GET.get('num_tours', None)
    lat = request.GET.get('lat', None)
    lon = request.GET.get('lon', None)

    queryset = Tour.objects.filter(parent_tours__isnull=True, is_subtour=False)

    if category:
        queryset = queryset.filter(category__iexact=category)

    if search_term:
        queryset = queryset.filter(
            Q(title__icontains=search_term) |
            Q(place__icontains=search_term)
        )

    if sort_param in ['true', '1', 'yes']:
        queryset = queryset.order_by('creation_time')

    if num_tours:
        try:
            limit = int(num_tours)
            if limit > 0:
                queryset = queryset[:limit]
        except (ValueError, TypeError):
            pass

    tours_list = list(queryset)

    if lat and lon:
        lat = float(lat)
        lon = float(lon)
        for tour in tours_list:
            tour_lat, tour_lon = parse_coordinates(tour.coordinates)
            if tour_lat is not None and tour_lon is not None:
                tour.distance = distance(lat, lon, tour_lat, tour_lon)
            else:
                tour.distance = float('inf')
        
        tours_list.sort(key=lambda x: x.distance)

    print("Tours list: ", tours_list, flush=True)
    serializer = TourSerializer(tours_list, many=True)
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

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cut_map(request, tour_id):
    storage = MinioStorage()

    try:
        tour = Tour.objects.get(pk=tour_id)
    except Tour.DoesNotExist:
        return JsonResponse({"error": "Tour not found"}, status=400)

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
    print("BBOX: ", min_lon, min_lat, max_lon, max_lat, flush=True)
    bbox = f"{min_lon - 0.1},{min_lat - 0.1},{max_lon + 0.1},{max_lat + 0.1}"
    print("BBOX: ", bbox, flush=True)

    payload = {
        "tour_id": str(tour_id),
        "bbox": bbox
    }
    url = "http://pmtiles-server:8081/extract"
    headers = {"Content-type": "application/json"}
    response = requests.post(url, headers=headers, json=payload)
    if response.status_code != 200:
        return JsonResponse({"error": "Failed to extract pmtiles"}, status=400)
    
    file = storage.open(f"/{tour_id}/tour_{tour_id}.pmtiles", mode='rb')
    return FileResponse(file, as_attachment=True, filename=f"tour_{tour_id}.pmtiles")