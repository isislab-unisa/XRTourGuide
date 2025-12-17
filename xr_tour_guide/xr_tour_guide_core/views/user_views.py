# from rest_framework.response import Response
# from rest_framework import status
# from ..serializers import PasswordResetSerializer, PasswordResetConfirmSerializer, RegisterSerializer, UserSerializer
# from rest_framework.permissions import IsAuthenticated
# from rest_framework.decorators import api_view, permission_classes, authentication_classes
# from rest_framework.permissions import IsAuthenticated
# from rest_framework.permissions import AllowAny
# from drf_yasg.utils import swagger_auto_schema
# from drf_yasg import openapi
# from rest_framework import generics, status
# from rest_framework.response import Response
# from django.urls import reverse
# from django.core.mail import send_mail
# from django.utils.http import urlsafe_base64_encode
# from django.utils.encoding import force_bytes
# from django.contrib.auth.tokens import default_token_generator
# from django.utils.http import urlsafe_base64_decode
# from django.shortcuts import get_object_or_404
# from rest_framework.views import APIView
# from django.contrib.auth import get_user_model
# from django.shortcuts import render, redirect
# from django.views import View
# from ..authentication import JWTFastAPIAuthentication

# @swagger_auto_schema(
#     method='get',
#     operation_summary="Retrieve the current authenticated user's profile",
#     responses={200: UserSerializer()}
# )
# @api_view(['GET'])
# @authentication_classes([JWTFastAPIAuthentication])
# @permission_classes([IsAuthenticated])
# def profile_details(request):
#     user = request.user
#     serializer = UserSerializer(user)
#     return Response(serializer.data, status=status.HTTP_200_OK)

# @swagger_auto_schema(
#     method='post',
#     operation_summary="Update the current authenticated user's profile",
#     request_body=openapi.Schema(
#         type=openapi.TYPE_OBJECT,
#         properties={
#             'firstName': openapi.Schema(type=openapi.TYPE_STRING),
#             'lastName': openapi.Schema(type=openapi.TYPE_STRING),
#             'email': openapi.Schema(type=openapi.TYPE_STRING, format='email'),
#             'description': openapi.Schema(type=openapi.TYPE_STRING),
#         }
#     ),
#     responses={200: openapi.Response(description="Profile updated successfully")}
# )
# @api_view(['POST'])
# @authentication_classes([JWTFastAPIAuthentication])
# @permission_classes([IsAuthenticated])
# def update_profile(request):
#     user = request.user
#     first_name = request.data.get('firstName', '').strip()
#     last_name = request.data.get('lastName', '').strip()
#     email = request.data.get('email', '').strip()
#     description = request.data.get('description', '').strip()

#     if first_name:
#         user.first_name = first_name
#     if last_name:
#         user.last_name = last_name
#     if email:
#         user.email = email
#     if user.description == description:
#         user.description = description

#     user.save()
#     return Response({"detail": "Profile updated successfully."}, status=status.HTTP_200_OK)

# @swagger_auto_schema(
#     method='post',
#     operation_summary="Update the user's password",
#     request_body=openapi.Schema(
#         type=openapi.TYPE_OBJECT,
#         required=['oldPassword', 'newPassword'],
#         properties={
#             'oldPassword': openapi.Schema(type=openapi.TYPE_STRING),
#             'newPassword': openapi.Schema(type=openapi.TYPE_STRING),
#         }
#     ),
#     responses={
#         200: openapi.Response(description="Password updated successfully"),
#         400: openapi.Response(description="Old password is incorrect")
#     }
# )
# @api_view(['POST'])
# @authentication_classes([JWTFastAPIAuthentication])
# @permission_classes([IsAuthenticated])
# def update_password(request):
#     user = request.user
#     old_password = request.data.get('oldPassword')
#     new_password = request.data.get('newPassword')

#     if not user.check_password(old_password):
#         return Response({"detail": "Old password is incorrect."}, status=status.HTTP_400_BAD_REQUEST)

#     user.set_password(new_password)
#     user.save()
#     return Response({"detail": "Password updated successfully."}, status=status.HTTP_200_OK)

# @swagger_auto_schema(
#     method='post',
#     operation_summary="Delete the current user's account",
#     request_body=openapi.Schema(
#         type=openapi.TYPE_OBJECT,
#         required=['password'],
#         properties={
#             'password': openapi.Schema(type=openapi.TYPE_STRING)
#         }
#     ),
#     responses={
#         200: openapi.Response(description="Account deleted successfully"),
#         400: openapi.Response(description="Password is incorrect")
#     }
# )
# @api_view(['POST'])
# @authentication_classes([JWTFastAPIAuthentication])
# @permission_classes([IsAuthenticated])
# def delete_account(request):
#     user = request.user
#     password = request.data.get('password')

#     if not user.check_password(password):
#         return Response({"detail": "Password is incorrect."}, status=status.HTTP_400_BAD_REQUEST)

#     user.delete()
#     return Response({"detail": "Account deleted successfully."}, status=status.HTTP_200_OK)


# @api_view(['POST'])
# @authentication_classes([JWTFastAPIAuthentication])
# @permission_classes([IsAuthenticated])
# def forgot_password(request):
#     return Response({"detail": "Password reset email sent successfully."}, status=status.HTTP_200_OK)

# class RegisterView(generics.CreateAPIView):
#     queryset = get_user_model().objects.all()
#     serializer_class = RegisterSerializer
#     permission_classes = [AllowAny]

#     def perform_create(self, serializer):
#         user = serializer.save()
#         token = default_token_generator.make_token(user)
#         uid = urlsafe_base64_encode(force_bytes(user.pk))
#         activation_link = self.request.build_absolute_uri(
#             reverse('activate-account', kwargs={'uidb64': uid, 'token': token})
#         )
#         send_mail(
#             subject='Activate your account',
#             message=f'Click here to activate the account: {activation_link}',
#             from_email=None,
#             recipient_list=[user.email]
#         )

# class ActivateAccountView(APIView):
#     permission_classes = [AllowAny]
#     def get(self, request, uidb64, token):
#         try:
#             uid = urlsafe_base64_decode(uidb64).decode()
#             user = get_object_or_404(get_user_model(), pk=uid)
#         except (TypeError, ValueError, OverflowError, get_user_model().DoesNotExist):
#             return Response({'error': 'Link non valido'}, status=400)

#         if default_token_generator.check_token(user, token):
#             user.is_active = True
#             user.save()
#             return Response({'message': 'Account attivato correttamente'}, status=200)
#         return Response({'error': 'Token non valido'}, status=400)

# @permission_classes([AllowAny])
# class PasswordResetView(generics.GenericAPIView):
#     serializer_class = PasswordResetSerializer

#     def post(self, request, *args, **kwargs):
#         serializer = self.get_serializer(data=request.data, context={'request': request})
#         serializer.is_valid(raise_exception=True)
#         serializer.save()
#         return Response({"detail": "Email sent with instructions to reset the password."})

# @permission_classes([AllowAny])
# class PasswordResetConfirmView(generics.GenericAPIView):
#     serializer_class = PasswordResetConfirmSerializer

#     def post(self, request, *args, **kwargs):
#         serializer = self.get_serializer(data=request.data)
#         serializer.is_valid(raise_exception=True)
#         serializer.save()
#         return Response({"detail": "Password updated successfully."})

# class PasswordResetConfirmPage(View):
#     def get(self, request, uidb64, token):
#         context = {'uidb64': uidb64, 'token': token}
#         return render(request, 'password_reset_confirm.html', context)

# class PasswordResetConfirmSubmit(View):
#     def post(self, request, uidb64, token):
#         new_password = request.POST.get('new_password')
#         try:
#             uid = urlsafe_base64_decode(uidb64).decode()
#             user = get_user_model().objects.get(pk=uid)
#         except Exception:
#             return render(request, 'password_reset_confirm.html', {'error': 'Link non valido', 'uidb64': uidb64, 'token': token})

#         if not default_token_generator.check_token(user, token):
#             return render(request, 'password_reset_confirm.html', {'error': 'Token scaduto o non valido', 'uidb64': uidb64, 'token': token})

#         user.set_password(new_password)
#         user.save()
#         return redirect('/')