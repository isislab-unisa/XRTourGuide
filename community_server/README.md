# XRTourGuide Community Server

<p align="center">
  <img src="https://via.placeholder.com/800x200?text=XRTourGuide+Community+Server" alt="XRTourGuide Community Server Banner" />
</p>

<p align="center">
  <strong>The open-source identity provider powering unified XR rural communities.</strong>
</p>

---

## 🚀 Overview

The **XRTourGuide Community Server** is an open-source identity provider designed to unify and empower communities built around XRTourGuide servers. Its mission is to strengthen the visibility and impact of rural communities by providing secure, scalable, and user‑friendly tools.

Built with **FastAPI**, secured with **OAuth 2.0**, and backed by **MySQL**, the Community Server provides:

* 🔐 User authentication & authorization
* ⚙️ Community management APIs
* 🗄️ Secure data storage
* 🖥️ A modern, user-friendly administration interface

The server is fully open-source and licensed under the **MIT License**, so you're free to use, modify, and contribute.

---

## 📦 Features

* **FastAPI‑powered REST APIs** for high performance
* **OAuth 2.0 authentication** for secure access
* **MySQL database** support
* **Docker-ready deployment**
* **Automatic default admin user creation**
* **Extensible & Community‑focused** architecture

---

## 🛠️ Getting Started

Follow these steps to run the Community Server locally.

### 1️⃣ Clone the repository

```bash
git clone https://github.com/isislab-unisa/XRTourGuide
cd community-server
```

### 2️⃣ Install Docker

Download and install Docker from the official website.

### 3️⃣ Install Python requirements

```bash
pip install -r requirements.txt
```

### 4️⃣ Create your `.env` file

Create a `.env` file in the project root and include:

```
DB_NAME="your_db_name"
DB_USER="your_user"
DB_PASSWORD="your_password"
DB_HOST="your_host"
DB_PORT="your_port"

DEFAULT_USER_NAME="admin"
DEFAULT_USER_EMAIL="admin@example.com"
DEFAULT_USER_PASSWORD="change_me"

SECRET_KEY="your_secret_key"
```

### 5️⃣ Start the server with Docker

```bash
docker-compose up -d --build
```

Once running, you can access:

* **API Docs:** `http://localhost:8002/docs`
* **Admin Interface:** `http://localhost:8002`

---

## 📁 Project Structure

```
community-server/
├── app/
│   ├── api/
│   ├── models/
│   ├── core/
│   └── ...
├── docker-compose.yml
├── requirements.txt
└── .env
```

---

## 🤝 Contributing

We welcome contributions! Whether you're fixing bugs, improving documentation, or adding new features:

1. Fork the repository
2. Create a new branch
3. Submit a pull request

---

## 📜 License

This project is licensed under the **MIT License** — free to use and modify.

---

<p align="center">Made with ❤️ for the XRTourGuide</p>
