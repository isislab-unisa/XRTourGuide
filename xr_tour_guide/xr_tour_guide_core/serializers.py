from rest_framework import serializers
from .models import Tour, Review, Waypoint, WaypointViewImage
from django.contrib.auth import get_user_model

class WaypointViewImageSerializer(serializers.ModelSerializer):
    image_name = serializers.SerializerMethodField()

    class Meta:
        model = WaypointViewImage
        fields = ['waypoint', 'image_name']

    def get_image_name(self, obj):
        return obj.image.name if obj.image else None
        
class WaypointSerializer(serializers.ModelSerializer):
    images = WaypointViewImageSerializer(many=True, read_only=True)
    lat = serializers.SerializerMethodField()
    lon = serializers.SerializerMethodField()

    class Meta:
        model = Waypoint
        fields = [
            'title', 'coordinates', 'tour', 'description',
            'images', 'lat', 'lon'
        ]

    def get_lat(self, obj):
        return obj.coordinates.split(',')[0]
    
    def get_lon(self, obj):
        return obj.coordinates.split(',')[1]
    
    def get_pdf_name(self, obj):
        return obj.pdf_item.name if obj.pdf_item else None

    def get_readme_name(self, obj):
        return obj.readme_item.name if obj.readme_item else None

    def get_video_name(self, obj):
        return obj.video_item.name if obj.video_item else None

    def get_audio_name(self, obj):
        return obj.audio_item.name if obj.audio_item else None
    
class TourSerializer(serializers.ModelSerializer):
    creation_time = serializers.SerializerMethodField()
    user_name = serializers.SerializerMethodField()
    default_img = serializers.SerializerMethodField()
    lat = serializers.SerializerMethodField()
    lon = serializers.SerializerMethodField()
    class Meta:
        model = Tour
        fields = ['title', 'subtitle', 'place', 'category', 'description', 'user', 'lat', 'lon', 'default_img', 'creation_time', 'counter_review', 'user_name', 'id']

    def get_lat(self, obj):
        return obj.coordinates.split(',')[0]
    
    def get_lon(self, obj):
        return obj.coordinates.split(',')[1]
    
    def get_default_img(self, obj):
        return obj.default_image.name if obj.default_image else None
    
    def get_creation_time(self, obj):
        return obj.creation_time.strftime("%Y-%m-%d")
    
    def get_user_name(self, obj):
        return obj.user.username
    
class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = get_user_model()
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'city', 'description']

class ReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = '__all__'

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = get_user_model()
        fields = ['username', 'email', 'password', 'first_name', 'last_name', 'city', 'description']

    def create(self, validated_data):
        user = get_user_model().objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data['first_name'],
            last_name=validated_data['last_name'],
            city=validated_data['city'],
            description=validated_data['description'],
            is_active=False,
            is_staff = True
        )
        return user