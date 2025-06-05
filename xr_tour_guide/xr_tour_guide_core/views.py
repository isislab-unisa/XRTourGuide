from django.shortcuts import render
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Tour
from .serializers import TourSerializer
from django.db.models import Q

@api_view(['GET'])
def tour_list(request, category):
    searchTerm = request.GET.get('searchTerm', '')
    filters = Q(categoria__iexact=category)
    if searchTerm:
        filters &=Q(nome__icontains=searchTerm) | Q(sottotitolo__icontains=searchTerm) | Q(descrizione__icontains=searchTerm) | Q(luogo__icontains=searchTerm) | Q(coordinate__icontains=searchTerm)
    tours = Tour.objects.filter(filters)
    serializer = TourSerializer(tours, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)