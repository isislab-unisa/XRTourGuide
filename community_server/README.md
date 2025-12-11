# Community Server

XRTourGuide Community Server is an open-source identity provider that allows to create a community for XRTourGuide servers. The aim is to unify all of those communities to improve the impact of valorizing the rural communities.

The Community Server offers a set of APIs to manage the community, including user authentication, authorization, and data storage. The server also provides a user-friendly interface for managing the community and its data.

The Community Server is built using FastAPI, and is designed to be scalable and secure. The server uses OAuth 2.0 for authentication and authorization, and uses MySQL as its database.

The Community Server is open-source and is available on GitHub. The server is licensed under the MIT License, which allows for free use and modification of the source code.

## Getting Started

To get started with the Community Server, you will need to:

1. Clone the repository using Git.
2. Install Docker.
3. Install the requirements listed in `requirements.txt`.
4. Create a `.env` file with the required environment variables.

Once you have completed these steps, you can start the container using Docker and access the Community Server's APIs and user interface.

### The .env file needs:
- DB_NAME="XXX"
- DB_USER="XXX"
- DB_PASSWORD="XXX"
- DB_HOST="XXX"
- DB_PORT="XXX"

- DEFAULT_USER_NAME="XXX"
- DEFAULT_USER_EMAIL="XXX"
- DEFAULT_USER_PASSWORD="XXX"

- SECRET_KEY="XXX"
