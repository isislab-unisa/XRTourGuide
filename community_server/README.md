# XRTourGuide Community Server

<p align="center">
  <img src="../assets/logo.png" alt="XRTourGuide Community Server" width="200"/>
</p>

<h3 align="center">An open-source identity provider for XRTourGuide</h3>

<p align="center">
  Empowering rural communities through secure, scalable authentication infrastructure
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-documentation">Documentation</a> •
  <a href="#-contributing">Contributing</a> •
  <a href="#-community">Community</a>
</p>

<p align="center">
  <a href="https://github.com/isislab-unisa/XRTourGuide/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
  </a>
  <a href="https://github.com/isislab-unisa/XRTourGuide/stargazers">
    <img src="https://img.shields.io/github/stars/isislab-unisa/XRTourGuide?style=social" alt="Stars">
  </a>
  <a href="https://github.com/isislab-unisa/XRTourGuide/network/members">
    <img src="https://img.shields.io/github/forks/isislab-unisa/XRTourGuide?style=social" alt="Forks">
  </a>
  <a href="https://github.com/isislab-unisa/XRTourGuide/issues">
    <img src="https://img.shields.io/github/issues/isislab-unisa/XRTourGuide" alt="Issues">
  </a>
  <a href="https://github.com/isislab-unisa/XRTourGuide/pulls">
    <img src="https://img.shields.io/github/issues-pr/isislab-unisa/XRTourGuide" alt="Pull Requests">
  </a>
</p>

---

## 🌟 Overview

**XRTourGuide Community Server** is an open-source identity provider built to unify and empower communities around XRTourGuide servers.

### Why XRTourGuide Community Server?

- **Secure by Design** - OAuth 2.0 authentication
- **Fast & Modern** - Built on FastAPI for high performance
- **Community-First** - Designed with rural communities in mind
- **Developer-Friendly** - Clear APIs, great documentation, easy to extend
- **Deploy Anywhere** - Docker-ready for seamless deployment

---

## Features

### Core Capabilities

- **User Authentication & Authorization** - Secure OAuth 2.0 implementation
- **Community Management** - Comprehensive APIs for community operations
- **Reliable Data Storage** - MySQL-backed persistence layer
- **Admin Dashboard** - Modern, intuitive administration interface

### Technical Stack

- **Backend:** FastAPI (Python 3.9+)
- **Database:** MySQL 8.0+
- **Authentication:** OAuth 2.0 / JWT
- **Containerization:** Docker & Docker Compose
- **Documentation:** OpenAPI (Swagger)

---

## Quick Start

Get up and running in minutes with Docker!

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (1.29+)
- Git

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/isislab-unisa/XRTourGuide.git
cd XRTourGuide/community-server
```

2. **Configure environment variables**

Create a `.env` file in the project root:

```bash
# Database Configuration
CS_DB_NAME=xrtourguide
CS_DB_USER=your_admin
CS_DB_PASSWORD=password
CS_DB_HOST=db
CS_DB_PORT=3306

# Default Admin User
DEFAULT_USER_NAME=your_admin
DEFAULT_USER_EMAIL=admin@example.com
DEFAULT_USER_PASSWORD=password

# Security
SECRET_KEY=your_secret_key_here_generate_with_openssl_rand_hex_32
JWT_SECRETY=your_secret_key_here_generate_with_openssl_rand_hex_32

# Endpoint
BASE_UR="https://your_domain_name/communityserver"
```

> 💡 **Tip:** Generate a secure secret key with: `openssl rand -hex 32`

3. **Launch with Docker**

```bash
docker-compose up -d --build
```

4. **Verify installation**

- **API Documentation:** http://localhost:8002/docs
- **Admin Interface:** http://localhost:8002
- **Health Check:** http://localhost:8002/health

---

## Documentation

### API Reference

Once running, explore the interactive API documentation:

- **Swagger UI:** http://localhost:8002/docs

### Project Structure

```
community-server/
├── app/                   # API endpoints
├── model/                 # Database models
│   └── models/            # Pydantic schemas
    └── database           # DB
├── templates/             # HTML templates
├── docker-compose.yml     # Docker orchestration
├── Dockerfile             # Container definition
├── requirements.txt       # Python dependencies
└── README.md              # This file
```

---

## Contributing

We love contributions! Whether you're fixing bugs, improving docs, or proposing new features, your help is welcome.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
4. **Commit with clear messages**
   ```bash
   git commit -m "Add amazing feature"
   ```
5. **Push to your fork**
   ```bash
   git push origin feature/amazing-feature
   ```
6. **Open a Pull Request**

### Development Setup

```bash
# Clone your fork
git clone https://github.com/isislab-unisa/XRTourGuide.git

cd community_server/

sudo docker compose up -d --build
```

---

## Issues & Support

### Reporting Bugs

Found a bug? Please [open an issue](https://github.com/isislab-unisa/XRTourGuide/issues/new) with:

- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- Your environment (OS, Python version, etc.)

### Feature Requests

Have an idea? We'd love to hear it! [Create a feature request](https://github.com/isislab-unisa/XRTourGuide/issues/new) and let's discuss.

---

## Community

Join our community and connect with other contributors!

- **GitHub Discussions:** [Join the conversation](https://github.com/isislab-unisa/XRTourGuide/discussions)
- **Issue Tracker:** [Report bugs or request features](https://github.com/isislab-unisa/XRTourGuide/issues)
- **Contact:** [isislab@unisa.it](mailto:isislab@unisa.it)

---

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2024 ISISLab - University of Salerno

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙏 Acknowledgments

- Built with ❤️ by [ISISLab](https://www.isislab.it/) at the University of Salerno
- Powered by the amazing [FastAPI](https://fastapi.tiangolo.com/) framework
- Thanks to all our [contributors](https://github.com/isislab-unisa/XRTourGuide/graphs/contributors)!

---

<p align="center">
  <sub>Made with ❤️ for rural communities worldwide</sub>
</p>

<p align="center">
  <a href="#xrtourguide-community-server">Back to Top ↑</a>
</p>