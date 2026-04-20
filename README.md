![introduction](./img/introduction.png)

# Quickstart

Instead of initializing your own repositroy you can just fork this one to you
own github account.
This repo is a substract of the [Microsoft archived repo](https://github.com/microsoft/MCW-Cloud-native-applications).

# Solution architecture

Below is a diagram of the solution architecture you will build in this lab. It consists of a web application working with a backend API and relying on data stored in a Mongo DB. This application is made publicly available without any user authentication requirements.

![Solution architecture](./img/diagrams-Solution%20overview.png)

# Run locally

## Develop with Dev Container

This repository now contains a ready-to-use Dev Container setup under `.devcontainer/`.

### Prerequisite

- Docker Desktop installed and running.
- VS Code extension: `Dev Containers`.

### Open in container

1. Open this repository in VS Code.
2. Run the command: `Dev Containers: Reopen in Container`.
3. Wait for the initial build and post-create dependency installation.

### Included tools

- Node.js via nvm (versions 10, 16, 20; default 16)
- Angular CLI 8.3.29
- MongoDB 4.0 service (docker-compose)
- Azure CLI + Bicep
- Docker CLI (host daemon access)

### Typical development commands inside the container

- Backend API: `npm --prefix content-api start`
- Data initialization: `node content-init/server.js`
- Frontend build (Angular): `npm --prefix content-web run build`
- Frontend server (Node/Express): `node content-web/app.js`
- Gateway (Envoy image build): `docker build -t content-gateway:1.0.0 ./content-gateway`

### Run web app with Node (recommended for `/api/*` routes)

If you want to keep the Node startup (instead of `ng serve`), use these steps.

1. Start backend API:

   npm --prefix content-api start

2. Seed data (if not already done):

   node content-init/server.js

3. Build Angular assets (one-time build):

   npm --prefix content-web run build

4. Start the web server with API target:

   node content-web/app.js

5. Open http://localhost:3000

Notes:

- For automatic front-end rebuilds while coding, run this in another terminal:

      npm --prefix content-web run build -- --watch

## Develop with Docker containers

### Database

First of all, initialize your database by executing the following commands:

      docker container run --name mongo -p 27017:27017 -d mongo:4.0

      #Navigate to your content-init directory
      cd ./content-init

      # Make sure you have node version 16 installed
      nvm use 16

      npm ci
      npm start

### Backend API

Make sure to get the proper Mongo DB connection string. To do that, get your IP Address where your mongo service is running:

      docker inspect mongo | grep IPAddress

And use the value returned in `IPAddress` to run your backend container

      cd ./content-api
      docker build -t content-api:1.0.0 .
      docker container run --name content-api -p 3001:3001 -e MONGODB_CONNECTION=mongodb://<IPAddress>:27017/contentdb  -d content-api:1.0.0

### Frontend

Make sure to get the proper backend api URL. To do that, get your IP Address where your mongo service is running:

      docker inspect content-api | grep IPAddress

And use the value returned in `IPAddress` to run your backend container

      cd ./content-web
      docker build -t content-web:1.0.0 .
      docker container run --name content-web -p 3000:3000 -e CONTENT_API_URL=http://<IPAddress>:3001 -d content-web:1.0.0

# Run in Azure

## Database

Azure Cosmos for Mongo DB enables us to use Mongo DB database as a service. In order to initialize the database,

1. Create an Azure Cosmos for Mongo DB
2. Create the database named `contentdb`
3. Execute the following commands:

   **PowerShell Core (Windows)**

            cd ./content-init
            $env:MONGODB_CONNECTION="mongodb://<ACCOUNT-NAME>:<PRIMARY-KEY>@<ACCOUNT-NAME>.mongo.cosmos.azure.com:10255/contentdb?ssl=true&replicaSet=globaldb&retrywrites=false"
            npm start

   **Bash (Ubuntu / MacOS)**

            cd ./content-init
            export MONGODB_CONNECTION="mongodb://<ACCOUNT-NAME>:<PRIMARY-KEY>@<ACCOUNT-NAME>.mongo.cosmos.azure.com:10255/contentdb?ssl=true&replicaSet=globaldb&retrywrites=false"
            npm start

4. When initialized, update the indexing policy of the automatically created `sessions` collection including the index on the field `startTime`, as illustrated in the image below. This property is used to sort sessions documents when fetched through the backend API.
    ![Indexing policy](./img/sessions-indexing-policy.png)

## Container registry

Our docker images are made available to our Azure services through an Azure Container Registry. The following commands enable you to publish your images into this registry.

> **Note (Apple Silicon / ARM Macs):** Azure Container Apps requires `linux/amd64` images. If you build on an Apple Silicon Mac (M1/M2/M3/M4), Docker produces `linux/arm64` images by default, which will fail at deployment with:
> `no child with platform linux/amd64 in index`.
> Use `--platform linux/amd64` on `docker build` to force a cross-platform build.

**PowerShell Core (Windows)**

      # Login with your account to Azure
      az login --tenant <tenant-id>

      # Get an access token to login to docker
      $TOKEN=$(az acr login --name <acrName> --expose-token --output tsv --query accessToken)
      docker login <acrName>.azurecr.io --username 00000000-0000-0000-0000-000000000000 --password $TOKEN

      # Build and publish your images
      cd ./content-api
      docker build -t <acrName>.azurecr.io/content/api:<tag> .
      docker push <acrName>.azurecr.io/content/api:<tag>

      cd ./content-web
      docker build -t <acrName>.azurecr.io/content/web:<tag> .
      docker push <acrName>.azurecr.io/content/web:<tag>

**Bash (Ubuntu / MacOS)**

      # Login with your account to Azure
      az login --tenant <tenant-id>

      # Get an access token to login to docker
      TOKEN=$(az acr login --name <acrName> --expose-token --output tsv --query accessToken)
      docker login <acrName>.azurecr.io --username 00000000-0000-0000-0000-000000000000 --password "$TOKEN"

      # Build and publish your images (--platform ensures compatibility with Azure Container Apps)
      cd ./content-api
      docker build --platform linux/amd64 -t <acrName>.azurecr.io/content/api:<tag> .
      docker push <acrName>.azurecr.io/content/api:<tag>

      cd ./content-web
      docker build --platform linux/amd64 -t <acrName>.azurecr.io/content/web:<tag> .
      docker push <acrName>.azurecr.io/content/web:<tag>

## Phase 1 - PoC

First of all, we start working on a proof of concept enabling us to validate our system in an Azure environment. During this phase, we will build and publish our docker images manually to the Azure Container Registry. Then, these images are deployed into Azure App Services.

The following schema illustrates the architecture we've built for this phase.

![Azure PoC architecture](./img/diagrams-Azure%20architecture%20-%20PoC.png)

## Phase 2 - Code deployment automation

As our PoC was successful, the next step is to automatise our code deployment to remove manual activities and to prepare our environment to code changes and fast release.

![Automation](./img/diagrams-Azure%20architecture%20-%20Code%20deployment%20automation.png)

## Phase 3 - Azure Container Apps with Dapr

In this phase, we migrate from Azure App Services to **Azure Container Apps** and leverage **Dapr** (Distributed Application Runtime) for secure, resilient service-to-service communication.

### Deployment

The entire infrastructure is defined as Bicep modules orchestrated by `infra/main.bicep`. Deploy it with:

```bash
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file infra/main.bicep \
  --parameters \
      webapiImageAndTag='<acrName>.azurecr.io/content/api:<tag>' \
      webappImageAndTag='<acrName>.azurecr.io/content/web:<tag>'
```

This deploys the following resources:

| Resource | Purpose |
|----------|---------|
| Container App Environment | Shared hosting environment with Log Analytics integration |
| `ca-content-api` | Backend API container (internal ingress only) |
| `ca-content-web` | Frontend web container (external ingress) |
| Managed Identity | Passwordless authentication to ACR and Key Vault |
| Cosmos DB (Mongo) | Database backend |
| Key Vault | Secret management (MongoDB connection string) |
| Application Insights | Distributed tracing and monitoring |

### Service-to-service communication with Dapr

Instead of calling `content-api` through its public FQDN, `content-web` uses **Dapr service invocation** to communicate with the backend. This provides several benefits:

- **mTLS encryption** — All inter-service traffic is automatically encrypted and mutually authenticated.
- **Service discovery** — No need to know the target URL; Dapr resolves services by their `appId`.
- **Built-in resiliency** — Automatic retries, timeouts, and circuit-breakers.
- **Distributed tracing** — W3C Trace Context headers are injected automatically.

#### How it works

Each Container App has a **Dapr sidecar** configured with a unique `appId`:

| Container App | Dapr App ID | Dapr Port | Ingress |
|---------------|-------------|-----------|---------|
| `ca-content-api` | `content-api` | 3001 | Internal |
| `ca-content-web` | `content-web` | 3000 | External |

The `content-web` application calls the Dapr sidecar running on `localhost:3500` instead of the remote API hostname:

```
# Before (direct call via public FQDN)
CONTENT_API_URL=https://ca-content-api.<defaultDomain>

# After (Dapr service invocation via local sidecar)
CONTENT_API_URL=http://localhost:3500/v1.0/invoke/content-api/method
```

When `content-web` makes a request such as `GET /sessions`, it translates to:

```
GET http://localhost:3500/v1.0/invoke/content-api/method/sessions
    │                          │                │       │
    │                          │                │       └─ Route on content-api
    │                          │                └───────── Dapr App ID
    │                          └────────────────────────── Dapr invoke API
    └───────────────────────────────────────────────────── Local sidecar
```

> **Note:** No application code change was required. The existing `content-web/app.js` already concatenates `CONTENT_API_URL + '/sessions'`, which naturally composes the correct Dapr invocation URL.

Since `content-api` is now configured with **internal ingress only**, it is no longer publicly accessible — all traffic must flow through the Dapr sidecar, enforcing a Zero Trust communication model.
