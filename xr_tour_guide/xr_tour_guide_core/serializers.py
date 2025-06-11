from rest_framework import serializers
from .models import Tour, Review, Waypoint, WaypointViewImage
from django.contrib.auth import get_user_model

class WaypointViewImageSerializer(serializers.ModelSerializer):
    image_name = serializers.SerializerMethodField()

    class Meta:
        model = WaypointViewImage
        fields = '__all__'

    def get_image_name(self, obj):
        return obj.image.name if obj.image else None
        
class WaypointSerializer(serializers.ModelSerializer):
    images = WaypointViewImageSerializer(many=True, read_only=True)
    class Meta:
        model = Waypoint
        fields = '__all__'
    
class TourSerializer(serializers.ModelSerializer):
    waypoints = WaypointSerializer(many=True, read_only=True)
    class Meta:
        model = Tour
        fields = '__all__'

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
