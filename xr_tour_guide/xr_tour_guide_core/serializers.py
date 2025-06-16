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
            'images', 'lat', 'lon', 'id'
        ]

    def get_lat(self, obj):
        return float(obj.coordinates.split(',')[0])
    
    def get_lon(self, obj):
        return float(obj.coordinates.split(',')[1])
    
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
    rating = serializers.SerializerMethodField()
    l_edited = serializers.SerializerMethodField()
    rating_counter = serializers.SerializerMethodField()
    class Meta:
        model = Tour
        fields = ['title', 'subtitle', 'place', 'category', 'description', 'user', 'lat', 'lon', 'default_img', 'creation_time', 'user_name', 'id', 'tot_view', 'l_edited', 'rating', 'rating_counter']


    def get_rating_counter(self, obj):
        if len(obj.reviews.all()) == 0:
            return 0
        return int(len(obj.reviews.all()))

    def get_l_edited(self, obj):
        return obj.last_edited.strftime("%Y-%m-%d")
    
    def get_rating(self, obj):
        if len(obj.reviews.all()) == 0:
            return 0.0
        return float(sum([review.rating for review in obj.reviews.all()])) / float(len(obj.reviews.all()))

        
    def get_lat(self, obj):
        return float(obj.coordinates.split(',')[0])
    
    def get_lon(self, obj):
        return float(obj.coordinates.split(',')[1])
    
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
    user_name = serializers.SerializerMethodField()
    creation_date = serializers.SerializerMethodField()
    class Meta:
        model = Review
        fields = ['tour', 'user', 'rating', 'comment', 'user_name', 'creation_date', 'id']
    
    def get_user_name(self, obj):
        return obj.user.username
    
    def get_creation_date(self, obj):
        return obj.timestamp.strftime("%Y-%m-%d")

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