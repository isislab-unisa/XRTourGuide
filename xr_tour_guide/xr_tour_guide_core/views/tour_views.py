import base64
import re
from rest_framework.response import Response
from rest_framework import status
from ..serializers import TourSerializer, WaypointSerializer
from django.db.models import Q
from rest_framework.permissions import IsAuthenticated
from django.http import JsonResponse, FileResponse
from rest_framework.decorators import api_view, permission_classes, authentication_classes
from rest_framework.permissions import IsAuthenticated
import mimetypes
from ..models import MinioStorage, Tour, Category, TypeOfImage
from rest_framework.permissions import AllowAny
from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi
from rest_framework import status
from rest_framework.response import Response
import requests
import math
from django.db.models import Case, When
from ..authentication import JWTFastAPIAuthentication
import os
import dotenv
from django.http import HttpResponse

dotenv.load_dotenv()

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
        ),
        openapi.Parameter(
            'category',
            openapi.IN_QUERY,
            description="Filter tours by category",
            type=openapi.TYPE_STRING
        ),
        openapi.Parameter(
            'sorted',
            openapi.IN_QUERY,
            description="Sort tours by creation time (true/false)",
            type=openapi.TYPE_STRING
        ),
        openapi.Parameter(
            'num_tours',
            openapi.IN_QUERY,
            description="Limit number of tours returned",
            type=openapi.TYPE_INTEGER
        ),
        openapi.Parameter(
            'lat',
            openapi.IN_QUERY,
            description="Latitude for distance-based sorting",
            type=openapi.TYPE_NUMBER
        ),
        openapi.Parameter(
            'lon',
            openapi.IN_QUERY,
            description="Longitude for distance-based sorting",
            type=openapi.TYPE_NUMBER
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
        tours_list = tours_list[:10]

    print("Tours list: ", tours_list, flush=True)
    serializer = TourSerializer(tours_list, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

@swagger_auto_schema(
    method='get',
    operation_summary="Retrieve details for a specific tour",
    manual_parameters=[
        openapi.Parameter(
            'pk',
            openapi.IN_PATH,
            description="ID of the tour",
            type=openapi.TYPE_INTEGER,
            required=True
        )
    ],
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
    operation_summary="Retrieve waypoints for a specific tour including sub-tours",
    manual_parameters=[
        openapi.Parameter(
            'tour_id',
            openapi.IN_PATH,
            description="ID of the tour",
            type=openapi.TYPE_INTEGER,
            required=True
        )
    ],
    responses={
        200: openapi.Response(
            description="Waypoints and sub-tours retrieved successfully",
            schema=openapi.Schema(
                type=openapi.TYPE_OBJECT,
                properties={
                    'waypoints': openapi.Schema(type=openapi.TYPE_ARRAY, items=openapi.Schema(type=openapi.TYPE_OBJECT)),
                    'sub_tours': openapi.Schema(type=openapi.TYPE_ARRAY, items=openapi.Schema(type=openapi.TYPE_OBJECT))
                }
            )
        ),
        404: openapi.Response(description="Tour not found")
    }
)
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
    method='post',
    operation_summary="Increment the view count for a specific tour",
    request_body=openapi.Schema(
        type=openapi.TYPE_OBJECT,
        required=['tour_id'],
        properties={
            'tour_id': openapi.Schema(type=openapi.TYPE_INTEGER, description='ID of the tour'),
        },
    ),
    responses={
        200: openapi.Response(description="Tour updated successfully"),
        404: openapi.Response(description="Tour not found")
    }
)
@api_view(['POST'])
@authentication_classes([JWTFastAPIAuthentication])
@permission_classes([AllowAny])
def increment_view_count(request):
    tour_id = request.data.get('tour_id')
    try:
        tour = Tour.objects.get(id=tour_id)
    except Tour.DoesNotExist:
        return Response({"detail": "Tour not found"}, status=status.HTTP_404_NOT_FOUND)

    tour.tot_view += 1
    tour.save()

    return Response({"detail": "View count incremented successfully"}, status=status.HTTP_200_OK)

@swagger_auto_schema(
    method='post',
    operation_summary="Extract and download pmtiles file for a tour based on waypoint coordinates",
    manual_parameters=[
        openapi.Parameter(
            'tour_id',
            openapi.IN_PATH,
            description="ID of the tour",
            type=openapi.TYPE_INTEGER,
            required=True
        )
    ],
    responses={
        200: openapi.Response(description="Pmtiles file returned successfully"),
        400: openapi.Response(description="Tour not found or invalid waypoints")
    }
)
@api_view(['POST'])
@authentication_classes([JWTFastAPIAuthentication])
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
    url = os.getenv("PMTILES_URL")
    headers = {"Content-type": "application/json"}
    response = requests.post(url, headers=headers, json=payload)
    if response.status_code != 200:
        return JsonResponse({"error": "Failed to extract pmtiles"}, status=400)
    
    file = storage.open(f"/{tour_id}/tour_{tour_id}.pmtiles", mode='rb')
    return FileResponse(file, as_attachment=True, filename=f"tour_{tour_id}.pmtiles")

@swagger_auto_schema(
    method='get',
    operation_summary="Generate deep link page for opening tour in mobile app or web",
    manual_parameters=[
        openapi.Parameter(
            'pk',
            openapi.IN_PATH,
            description="ID of the tour",
            type=openapi.TYPE_INTEGER,
            required=True
        )
    ],
    responses={
        200: openapi.Response(description="HTML page with deep link logic")
    }
)
@api_view(['GET'])
@permission_classes([AllowAny])
def tour_deep_link(request, pk):
    
    android_store = os.getenv("ANDROID_STORE")
    ios_store = os.getenv("IOS_STORE")
    
    domain = os.getenv("DOMAIN")
    domain = re.sub(r'^https?://', '', domain)
    domain_b64 = base64.b64encode(domain.encode()).decode()
    app_deep_link = f"xrtourguide://tour/{pk}?domain={domain_b64}"
    
    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Opening Tour...</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body {{
                font-family: Arial, sans-serif;
                text-align: center;
                padding: 50px;
                background: #f5f5f5;
            }}
            .loader {{
                margin: 20px auto;
                border: 5px solid #f3f3f3;
                border-top: 5px solid #3498db;
                border-radius: 50%;
                width: 50px;
                height: 50px;
                animation: spin 1s linear infinite;
            }}
            @keyframes spin {{
                0% {{ transform: rotate(0deg); }}
                100% {{ transform: rotate(360deg); }}
            }}
            .message {{
                margin-top: 20px;
                color: #666;
            }}
        </style>
    </head>
    <body>
        <div class="loader"></div>
        <div class="message" id="message">Opening tour...</div>
        
        <script>
            var appOpened = false;
            var redirected = false;
            
            function redirect() {{
                if (redirected) return;
                redirected = true;
                
                var isAndroid = /Android/i.test(navigator.userAgent);
                var isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
                var isMobile = isAndroid || isIOS;
                
                if (isMobile) {{
                    document.getElementById('message').textContent = 'App not installed. Redirecting to store...';
                    setTimeout(function() {{
                        if (isAndroid) {{
                            window.location.href = '{android_store}';
                        }} else if (isIOS) {{
                            window.location.href = '{ios_store}';
                        }}
                    }}, 500);
                }} else {{
                    document.getElementById('message').textContent = 'Redirecting to web page...';
                    setTimeout(function() {{
                        window.location.href = '/tour_details/{pk}/';
                    }}, 500);
                }}
            }}
            
            document.addEventListener('visibilitychange', function() {{
                if (document.hidden) {{
                    appOpened = true;
                }}
            }});
            
            window.addEventListener('blur', function() {{
                appOpened = true;
            }});
            
            var isAndroid = /Android/i.test(navigator.userAgent);
            var isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);
            var isMobile = isAndroid || isIOS;
            
            if (isMobile) {{
                var iframe = document.createElement('iframe');
                iframe.style.display = 'none';
                iframe.src = '{app_deep_link}';
                document.body.appendChild(iframe);
                
                setTimeout(function() {{
                    if (!appOpened && !document.hidden) {{
                        redirect();
                    }}
                }}, 1500);
            }} else {{
                redirect();
            }}
        </script>
    </body>
    </html>
    """
    
    return HttpResponse(html)

@swagger_auto_schema(
    method='get',
    operation_summary="Retrieve all tours with streaming links for default images and waypoint resources",
    responses={
        200: openapi.Response(
            description="List of tours with streaming links and waypoint resources",
            schema=TourSerializer(many=True)
        )
    }
)
@api_view(['GET'])
@permission_classes([AllowAny])
def tour_informations(request):
    tours = Tour.objects.all()
    serializer = TourSerializer(tours, many=True)
    data = serializer.data
    
    domain = os.getenv("DOMAIN")
    for tour_data in data:
        tour_id = tour_data['id']
        tour_data['default_img'] = f"{domain}stream_minio_resource/?tour={tour_id}&file=default_image"
        tour_data['deep_link'] = f"{domain}tour/{tour_id}/"
        
        tour = Tour.objects.get(id=tour_id)
        waypoints = tour.waypoints.all()
        waypoints_data = []
        
        for waypoint in waypoints:
            waypoint_info = {
                'id': waypoint.id,
                'title': waypoint.title,
                'resources': {}
            }
            
            if waypoint.pdf_item:
                waypoint_info['resources']['pdf'] = f"{domain}stream_minio_resource/?waypoint={waypoint.id}&file=pdf"
            if waypoint.readme_item:
                waypoint_info['resources']['readme'] = f"{domain}stream_minio_resource/?waypoint={waypoint.id}&file=readme"
            if waypoint.video_item:
                waypoint_info['resources']['video'] = f"{domain}stream_minio_resource/?waypoint={waypoint.id}&file=video"
            if waypoint.audio_item:
                waypoint_info['resources']['audio'] = f"{domain}stream_minio_resource/?waypoint={waypoint.id}&file=audio"
            if waypoint.links.exists():
                waypoint_info['resources']['links'] = [link.link for link in waypoint.links.all()]
            
            images = waypoint.images.filter(type_of_images=TypeOfImage.ADDITIONAL_IMAGES)
            if images.exists():
                waypoint_info['resources']['images'] = [f"{domain}stream_minio_resource/?waypoint={waypoint.id}&file={img.image.name}" for img in images]
            
            waypoints_data.append(waypoint_info)
        
        tour_data['waypoints_resources'] = waypoints_data
    
    return Response(data)