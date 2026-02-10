from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi

@swagger_auto_schema(
    method='get',
    operation_summary="Health check endpoint",
    responses={
        200: openapi.Response(
            description="Service is active",
            examples={
                "application/json": {
                    "status": "Active"
                }
            }
        )
    }
)
@api_view(['GET'])
@permission_classes([AllowAny])
def health_check(request):
    return Response({"status": "Active"}, status=status.HTTP_200_OK)