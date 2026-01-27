# XRTourGuide

<div align="center">
<img src="../assets/logo.png" width=20% heigth=20%>
<br><br>

![XRTourGuide](https://img.shields.io/badge/XR-TourGuide-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![FUTURAL](https://img.shields.io/badge/EU-FUTURAL-yellow)

**Guiding Real-Life Experiences with XR Content**

*Enriching reality with immersive media insights using Extended Reality (XR) and Artificial Intelligence (AI) to empower rural communities.*

[Website](https://isislab-unisa.github.io/XRTourGuide/) • [FUTURAL Project](https://futural-project.eu/it/)

</div>

---

## About

**XRTourGuide Community Server**  is the centralized identity provider (IdP) designed to manage authentication and service orchestration across multiple XRTourGuide instances. Built on FastAPI and OAuth 2.0, it provides secure, scalable authentication infrastructure that unifies disparate XRTourGuide deployments into a cohesive community platform.

### The Purpose
The Community Server addresses critical challenges in managing distributed XRTourGuide deployments:

- Unified Authentication: Single sign-on across multiple XRTourGuide instances
- Service Federation: Centralized management of registered XRTourGuide services
- Community Building: Creating connections between users across different regional deployments
- Token Management: Secure JWT token generation and validation for mobile applications
- Scalability: Supporting multiple independent XRTourGuide servers under one authentication umbrella

### Architecture Overview
The Community Server operates as the central authentication hub:

- **Identity Provider (IdP)** managing user credentials and profiles
- **Service Registry** maintaining information about registered XRTourGuide instances
- **Token Authority** issuing JWT tokens for authenticated mobile app access
- **Community Platform** enabling cross-instance user discovery and interaction

---

## Key Features

### OAuth 2.0 Authentication

The Community Server implements industry-standard OAuth 2.0 authentication flows, providing secure access control for web applications, mobile apps, and registered services.

**Authentication Flow:**
1. User credentials validated against secure database
2. JWT access token generated upon successful authentication
3. Token includes user identity and authorized service access
4. Mobile applications use token to authenticate with XRTourGuide instances
5. Refresh token mechanism for extended sessions

**Security Features:**
- Password hashing using industry-standard algorithms
- Secure token generation and validation
- Email verification for account activation
- Session management with configurable expiration

### User Management

#### Registration

New users register through the Community Server with comprehensive profile information.

**Required Information:**
- First Name
- Last Name
- Username (unique identifier)
- Email Address (verified)
- Password (securely hashed)
- City/Location
- Biography/Description

**Registration Process:**
1. User submits registration form via web interface or API
2. Community Server validates input and checks for existing accounts
3. Activation email sent to provided address
4. User activates account via secure email link
5. Account enabled and ready for authentication

#### Profile Management

Users can manage their profile information through dedicated endpoints.

**Manageable Fields:**
- Personal information updates
- Password changes
- Profile description modifications
- Location settings

### Service Registry

The Community Server maintains a registry of XRTourGuide instances, allowing administrators to add, manage, and monitor connected services.

**Service Information:**
- Service name and description
- Base URL endpoint
- Registration status

**Service Management:**
- Add new XRTourGuide instances to the community
- Remove or deactivate services
- Monitor service health and availability

### JWT Token Generation

A core function of the Community Server is generating secure JWT tokens for mobile applications.

**Token Capabilities:**
- User identity verification
- Service authorization
- Expiration management
- Signature validation
- Claims customization

**Mobile App Integration:**
The mobile application receives a JWT token after authentication, which it can then use to access any registered XRTourGuide instance. This eliminates the need for users to maintain separate credentials for each service.

---

## Technical Stack

### Backend Framework

**FastAPI (Python 3.9+)**
- High-performance asynchronous web framework
- Automatic API documentation generation
- Built-in data validation using Pydantic
- Native OAuth 2.0 support

### Database

**MySQL 8.0+**
- Relational database for user and service data
- Robust transaction support
- Scalable storage architecture
- Efficient query optimization

### Authentication

**OAuth 2.0 / JWT**
- Industry-standard authentication protocol
- Stateless token-based authorization
- Configurable token expiration
- Secure signature verification

### Deployment

**Docker & Docker Compose**
- Containerized application architecture
- Reproducible deployment environments
- Easy scaling and orchestration
- Isolated service dependencies

---

## API Endpoints

The Community Server exposes RESTful API endpoints for user management, authentication, and service registration.

### Authentication Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/register` | POST | Register a new user account |
| `/login` | POST | Authenticate user and receive JWT token |
| `/verify-email` | GET | Activate account via email verification link |
| `/refresh-token` | POST | Obtain new access token using refresh token |
| `/logout` | POST | Invalidate current session tokens |

### User Management Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/users/me` | GET | Retrieve authenticated user profile |
| `/users/me` | PUT | Update user profile information |
| `/users/me/password` | POST | Change user password |
| `/users/{user_id}` | GET | Retrieve public user profile by ID |
| `/users/search` | GET | Search users within the community |

### Service Management Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/services` | GET | List all registered XRTourGuide services |
| `/services` | POST | Register a new XRTourGuide instance |
| `/services/{service_id}` | GET | Retrieve service details |
| `/services/{service_id}` | PUT | Update service information |
| `/services/{service_id}` | DELETE | Remove service from registry |

### Token Management Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/token/mobile` | POST | Generate JWT token for mobile application |
| `/token/validate` | POST | Validate JWT token signature and claims |
| `/token/revoke` | POST | Revoke specific token |

---

## Contributing

We welcome contributions from the community to improve the XRTourGuide Community Server.

### How to Contribute

1. Fork the repository
2. Create a feature branch
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Implement your changes with clear commit messages
4. Write or update tests as needed
5. Update documentation for new features
6. Push to your fork
   ```bash
   git push origin feature/your-feature-name
   ```
7. Open a Pull Request with detailed description

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

## Acknowledgments

This project has received funding from the European Union's Horizon 2020 research and innovation programme under the [FUTURAL](https://futural-project.eu/it/) initiative.

---

## Contact & Support

- **Project Website**: [isislab-unisa.github.io/XRTourGuide](https://isislab-unisa.github.io/XRTourGuide/)
- **FUTURAL Project**: [futural-project.eu](https://futural-project.eu/it/)
- **Research Group**: [ISISLab - UNISA](https://www.isislab.it/)
- **Email**: [isislab@unisa.it](mailto:isislab@unisa.it)
- **GitHub Issues**: [Report bugs or request features](https://github.com/isislab-unisa/XRTourGuide/issues)

---

<div align="center">
<sub>Made with dedication for rural communities worldwide</sub>
<br>
<sub>Part of the FUTURAL Project</sub>
</div>