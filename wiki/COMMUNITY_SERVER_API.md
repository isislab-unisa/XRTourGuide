# XRTourGuide Community Server API Documentation

## Overview

The XRTourGuide Community Server API provides authentication, user management, profile management, and service registration endpoints.

**Base URL:** To be configured  
**Version:** 0.1.0  
**Framework:** FastAPI

---

## Endpoints

### Authentication

#### GET `/`
Root endpoint.

**Response:**
- `200`: Successful Response (HTML)

---

#### POST `/login/`
User login via form.

**Request Body (Form Data):**
- `email` (string, required): User email
- `password` (string, required): User password

**Response:**
- `200`: Successful Response (HTML)
- `422`: Validation Error

---

#### POST `/api/token/`
User login to get access and refresh tokens.

**Response:**
- `200`: Login successful
```json
{
  "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "username": "john_doe",
    "email": "john@example.com",
    "name": "John",
    "surname": "Doe",
    "city": "New York",
    "description": "Software developer"
  }
}
```
- `400`: Email and password required
- `401`: User not found, account not active, or invalid credentials

---

#### POST `/api/token/refresh/`
Refresh access token using refresh token.

**Response:**
- `200`: Access token refreshed successfully
```json
{
  "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```
- `400`: Invalid refresh token
- `404`: User not found

---

#### POST `/api/google-login/`
Login or register using Google OAuth.

**Request Body:**
```json
{
  "id_token": "google_id_token_here"
}
```

**Response:**
- `200`: Google login successful
```json
{
  "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "user": {
    "id": 1,
    "username": "john_doe",
    "email": "john@example.com",
    "name": "John",
    "surname": "Doe"
  }
}
```
- `400`: Email not provided by Google
- `401`: Invalid token issuer or account is deactivated
- `422`: Validation Error
- `500`: Google OAuth not configured or authentication error

---

#### POST `/api/verify/`
Verify access token and get user details.

**Request Body (Form Data):**
- `token` (string, required): Access token to verify

**Response:**
- `200`: Token verified successfully
```json
{
  "user_id": 1,
  "username": "john_doe",
  "email": "john@example.com",
  "type": "access",
  "id": 1,
  "name": "John",
  "surname": "Doe",
  "city": "New York",
  "description": "Software developer",
  "valid": true
}
```
- `401`: Invalid token
- `404`: User not found
- `422`: Validation Error

---

#### POST `/api_register/`
Register a new user account.

**Request Body:**
```json
{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "secure_password",
  "firstName": "John",
  "lastName": "Doe",
  "city": "New York",
  "description": "Software developer"
}
```

**Response:**
- `201`: Account created successfully
```json
{
  "message": "Account created successfully. Please verify your email."
}
```
- `400`: Email or username already in use, or email already verified
- `422`: Validation Error
- `500`: Email sending failed

---

#### GET `/verify-email`
Verify user email address.

**Query Parameters:**
- `token` (string, required): Email verification token

**Response:**
- `200`: Successful Response
- `422`: Validation Error

---

#### POST `/resend-verification/`
Resend email verification link.

**Response:**
- `200`: Verification email sent successfully
```json
{
  "message": "Verification email sent again"
}
```
- `400`: Email already verified
- `404`: Email not found
- `500`: Email sending failed

---

#### POST `/reset-password/`
Request password reset email.

**Response:**
- `200`: Password reset email sent successfully
```json
{
  "message": "Password reset email sent"
}
```
- `404`: Email not found
- `500`: Email sending failed

---

#### GET `/reset-password/`
Get password reset form.

**Query Parameters:**
- `token` (string, required): Password reset token

**Response:**
- `200`: Successful Response
- `422`: Validation Error

---

#### POST `/verify-reset-password/`
Verify and complete password reset.

**Request Body (Form Data):**
- `token` (string, required): Password reset token
- `password` (string, required): New password
- `confirm_password` (string, required): Password confirmation

**Response:**
- `200`: Successful Response
- `422`: Validation Error

---

### Services

#### GET `/list_services/`
List all services.

**Response:**
- `200`: List of all services retrieved successfully

---

#### GET `/get_services/`
Get active services with health check.

**Response:**
- `200`: List of active and healthy services

---

#### GET `/get_service/{service_id}`
Get service domain by ID.

**Path Parameters:**
- `service_id` (integer, required): ID of the service

**Response:**
- `200`: Service domain retrieved successfully
- `422`: Validation Error

---

#### GET `/register_service`
Display service registration form.

**Response:**
- `200`: Registration form displayed (HTML)
- `303`: Redirect to login or home

---

#### POST `/add_service/`
Add a new service (Admin only).

**Request Body (Form Data):**
- `name` (string, required): Service name
- `domain` (string, required): Service domain
- `requester_email` (string, required): Requester's email
- `active` (boolean, required): Service active status

**Response:**
- `200`: Service added successfully (HTML)
- `303`: Redirect to login
- `403`: Admin access required
- `422`: Validation Error

---

#### POST `/delete_service/{service_id}`
Delete a service (Admin only).

**Path Parameters:**
- `service_id` (integer, required): ID of the service

**Response:**
- `200`: Service deleted successfully (HTML)
- `303`: Redirect to login
- `403`: Admin access required
- `404`: Service not found
- `422`: Validation Error

---

#### POST `/status_service/{service_id}`
Toggle service active status (Admin only).

**Path Parameters:**
- `service_id` (integer, required): ID of the service

**Response:**
- `200`: Service status updated successfully (HTML)
- `303`: Redirect to login
- `403`: Admin access required
- `404`: Service not found
- `422`: Validation Error

---

#### POST `/regenerate_credentials/{service_id}`
Regenerate service credentials (Admin only).

**Path Parameters:**
- `service_id` (integer, required): ID of the service

**Response:**
- `200`: Credentials regenerated and email sent
```json
{
  "message": "Credentials regenerated and email sent",
  "email_sent_to": "example@example.com"
}
```
- `303`: Redirect to login
- `403`: Admin access required
- `404`: Service not found
- `422`: Validation Error
- `500`: Credentials regenerated but failed to send email

---

#### GET `/retrieve-credentials`
Retrieve service credentials using token.

**Query Parameters:**
- `token` (string, required): Credentials retrieval token

**Response:**
- `200`: Credentials page displayed (HTML)
- `422`: Validation Error

---

### Users

#### POST `/update_password/`
Update user password.

**Headers:**
- `Authorization`: Bearer token (required)

**Response:**
- `200`: Password updated successfully
```json
{
  "message": "Password updated successfully"
}
```
- `401`: Authorization header missing, invalid, or incorrect credentials

---

#### POST `/delete_account/`
Delete user account.

**Headers:**
- `Authorization`: Bearer token (required)

**Response:**
- `200`: Account deleted successfully
```json
{
  "message": "Account deleted successfully"
}
```
- `401`: Authorization header missing, invalid, or incorrect credentials

---

### Profile

#### GET `/profile_detail/`
Retrieve authenticated user profile details.

**Headers:**
- `Authorization`: Bearer token (required)

**Response:**
- `200`: User profile retrieved successfully
```json
{
  "id": 1,
  "username": "johndoe",
  "email": "john@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "city": "New York",
  "description": "Software developer"
}
```
- `401`: Authorization header missing or invalid
- `404`: User not found

---

#### POST `/update_profile/`
Update authenticated user profile.

**Headers:**
- `Authorization`: Bearer token (required)

**Response:**
- `200`: Profile updated successfully
```json
{
  "message": "Profile updated successfully"
}
```
- `401`: Authorization header missing or invalid
- `404`: User not found

---

## Data Models

### User Registration
```json
{
  "username": "johndoe",
  "email": "john@example.com",
  "password": "secure_password",
  "firstName": "John",
  "lastName": "Doe",
  "city": "New York",
  "description": "Software developer"
}
```

### Google Login Request
```json
{
  "id_token": "google_id_token_string"
}
```

### Service
```json
{
  "name": "Service Name",
  "domain": "https://service.example.com",
  "requester_email": "admin@example.com",
  "active": true
}
```

---

## Authentication

Most endpoints require JWT Bearer token authentication. Include the token in the request header:

```
Authorization: Bearer <access_token>
```

**Token Types:**
- **Access Token**: Short-lived token for API access
- **Refresh Token**: Long-lived token to obtain new access tokens

---

## Error Responses

Common error responses across endpoints:

- `400`: Bad Request - Invalid parameters or missing required fields
- `401`: Unauthorized - Invalid or missing authentication
- `403`: Forbidden - Insufficient permissions
- `404`: Not Found - Requested resource does not exist
- `422`: Validation Error - Request validation failed
- `500`: Internal Server Error - Server-side error occurred

---

## Notes

- Admin-only endpoints require elevated privileges
- Email verification is required for new user accounts
- Service credentials are sent via email when regenerated
- Password reset tokens are time-limited
