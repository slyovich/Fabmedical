# Content Gateway

API Gateway basé sur [Envoy Proxy](https://www.envoyproxy.io/) qui centralise le routage et la sécurité de l'application Fabmedical.

## Architecture

```
                    ┌──────────────────────┐
                    │   Envoy Proxy (:8080)│
                    │                      │
Utilisateur ──────► │  OAuth2 (Entra ID)   │
                    │  JWT Authentication  │
                    │  RBAC Authorization  │
                    │                      │
                    │  /api/* ──► content-api  (:3001)
                    │  /*     ──► content-web  (:3000)
                    └──────────────────────┘
```

### Chaîne de filtres HTTP

| #   | Filtre        | Rôle                                                                                              |
| --- | ------------- | ------------------------------------------------------------------------------------------------- |
| 1   | **OAuth2**    | Gère le flow OIDC avec Entra ID. Redirige les utilisateurs non authentifiés vers la page de login |
| 2   | **JWT Authn** | Valide le JWT access token et extrait les claims dans les metadata                                |
| 3   | **RBAC**      | Autorise l'accès aux endpoints `/api/` selon le claim `roles` du JWT                              |
| 4   | **Router**    | Route vers le backend approprié                                                                   |

### Routage

| Requête entrante | Backend            | Path rewrite |
| ---------------- | ------------------ | ------------ |
| `/api/speakers`  | `content-api:3001` | `/speakers`  |
| `/api/sessions`  | `content-api:3001` | `/sessions`  |
| `/api/stats`     | `content-api:3001` | `/stats`     |
| `/*`             | `content-web:3000` | _(inchangé)_ |

### Autorisations (RBAC)

| Endpoint           | Rôle requis             |
| ------------------ | ----------------------- |
| `/api/sessions`    | `user`                  |
| `/api/speakers`    | `user`                  |
| `/api/stats`       | `admin`                 |
| `/*` (content-web) | Authentifié (tout rôle) |

---

## Prérequis — Entra ID App Registration

Avant toute utilisation, configurez une App Registration dans Entra ID :

### 1. Créer l'App Registration

- **Azure Portal** → **Microsoft Entra ID** → **App registrations** → **New registration**
- **Redirect URIs** (Web) :
  - Local : `http://localhost:8080/callback`
  - Azure : `https://<app-name>.<region>.azurecontainerapps.io/callback`

### 2. Créer un Client Secret

- **Certificates & secrets** → **New client secret**
- Notez la valeur (utilisée comme `CLIENT_SECRET`)

### 3. Exposer une API

- **Expose an API** → **Set** l'Application ID URI (par défaut : `api://<CLIENT_ID>`)
- **Add a scope** :
  - Scope name : `user_impersonation`
  - Who can consent : Admins and users
  - Admin consent display name : `Access Fabmedical API`

### 4. Configurer les App Roles

- **App roles** → Créer deux rôles :

| Display name | Value   | Allowed member types |
| ------------ | ------- | -------------------- |
| User         | `user`  | Users/Groups         |
| Admin        | `admin` | Users/Groups         |

### 5. Assigner les utilisateurs

- **Enterprise Applications** → Sélectionner l'application → **Users and groups**
- Ajouter les utilisateurs/groupes avec le rôle approprié (`user` ou `admin`)

---

## Configuration et test en local

### Prérequis

- [Docker](https://docs.docker.com/get-docker/) installé
- Services backend lancés :
  - `content-api` sur le port **3001**
  - `content-web` sur le port **3000**

### Variables d'environnement

Le `TENANT_ID` et le `CLIENT_ID` sont substitués dans le fichier de configuration Envoy au démarrage du conteneur via `envsubst`. Le `CLIENT_SECRET` et le `HMAC_SECRET` sont lus nativement par Envoy via le type `DataSource`.

| Variable        | Description                                                | Exemple                                 |
| --------------- | ---------------------------------------------------------- | --------------------------------------- |
| `TENANT_ID`     | Azure AD Tenant ID                                         | `0b46db74-...`                          |
| `CLIENT_ID`     | Application (client) ID de l'App Registration              | `b8423ca0-...`                          |
| `CLIENT_SECRET` | Client secret de l'App Registration Entra ID               | `Tft8Q~...`                             |
| `HMAC_SECRET`   | Secret aléatoire pour signer les cookies de session OAuth2 | _(générer avec `openssl rand -hex 32`)_ |

### Build de l'image

```bash
docker build -t content-gateway:1.0.0 ./content-gateway
```

### Lancer le conteneur

```bash
docker run -d \
  --name content-gateway \
  -p 8080:8080 \
  -e TENANT_ID="<votre_tenant_id>" \
  -e CLIENT_ID="<votre_client_id>" \
  -e CLIENT_SECRET="<votre_client_secret>" \
  -e HMAC_SECRET="<votre_hmac_secret>" \
  content-gateway:1.0.0
```

> **Note** : sur macOS/Windows, les backends (`content-api`, `content-web`) doivent tourner sur la machine hôte. L'adresse `host.docker.internal` dans la configuration Envoy permet au conteneur de les joindre.

### Tester

1. Ouvrir [http://localhost:8080](http://localhost:8080) dans le navigateur
2. Vous êtes redirigé vers la page de login Entra ID
3. Après connexion, vous accédez à `content-web`
4. Tester les endpoints API :

```bash
# Ces endpoints nécessitent le rôle "user"
curl http://localhost:8080/api/speakers
curl http://localhost:8080/api/sessions

# Cet endpoint nécessite le rôle "admin"
curl http://localhost:8080/api/stats
```

### Endpoints spéciaux

| Path        | Description                                      |
| ----------- | ------------------------------------------------ |
| `/callback` | Callback OAuth2 (géré automatiquement par Envoy) |
| `/signout`  | Déconnexion — supprime la session et les cookies |

### Arrêter le conteneur

```bash
docker rm -f content-gateway
```

---

## Déploiement sur Azure Container Apps

### Architecture cible

```
Internet
  │
  ▼
┌──────────────────────────────────────────────────────┐
│          Azure Container Apps Environment            │
│                                                      │
│  ┌───────────────────┐                               │
│  │ content-gateway   │  Ingress externe (port 8080)  │
│  │ (Envoy Proxy)     │                               │
│  └──────┬───────┬────┘                               │
│         │       │                                    │
│    /api/│       │ /*                                 │
│         ▼       ▼                                    │
│  ┌─────────────┐ ┌─────────────┐                     │
│  │ content-api │ │ content-web │  Ingress interne    │
│  │ port 3001   │ │ port 3000   │                     │
│  └─────────────┘ └─────────────┘                     │
└──────────────────────────────────────────────────────┘
```

### 1. Préparer l'image

Pusher l'image vers Azure Container Registry :

```bash
# Login au registry
az acr login --name <acr_name>

# Tag et push
docker tag content-gateway:1.0.0 <acr_name>.azurecr.io/content-gateway:1.0.0
docker push <acr_name>.azurecr.io/content-gateway:1.0.0
```

### 2. Adapter la configuration Envoy

Pour Azure Container Apps, modifier les adresses des clusters dans `envoy.yaml` :

```yaml
# Remplacer host.docker.internal par les noms DNS internes des Container Apps
clusters:
  - name: content_api
    # ...
    address: content-api # Nom de la Container App
    port_value: 3001 # Port cible

  - name: content_web
    # ...
    address: content-web # Nom de la Container App
    port_value: 3000 # Port cible
```

> **Tip** : vous pouvez maintenir deux fichiers de configuration (`envoy.yaml` pour le local, `envoy-aca.yaml` pour Azure) ou utiliser un script de substitution.

### 3. Créer la Container App

```bash
# Créer le Container Apps Environment (si pas encore fait)
az containerapp env create \
  --name fabmedical-env \
  --resource-group <rg_name> \
  --location <location>

# Créer la Container App avec les secrets
az containerapp create \
  --name content-gateway \
  --resource-group <rg_name> \
  --environment fabmedical-env \
  --image <acr_name>.azurecr.io/content-gateway:1.0.0 \
  --registry-server <acr_name>.azurecr.io \
  --target-port 8080 \
  --ingress external \
  --secrets \
    client-secret="<votre_client_secret>" \
    hmac-secret="<votre_hmac_secret>" \
  --env-vars \
    TENANT_ID="<votre_tenant_id>" \
    CLIENT_ID="<votre_client_id>" \
    CLIENT_SECRET=secretref:client-secret \
    HMAC_SECRET=secretref:hmac-secret
```

### 4. Mettre à jour l'App Registration

Ajouter le **Redirect URI** de production dans l'App Registration :

- **Authentication** → **Web** → **Redirect URIs**
- Ajouter : `https://<app-name>.<region>.azurecontainerapps.io/callback`

### 5. (Optionnel) Utiliser Azure Key Vault pour les secrets

Pour une gestion centralisée des secrets :

```bash
# Activer l'identité managée sur la Container App
az containerapp identity assign \
  --name content-gateway \
  --resource-group <rg_name> \
  --system-assigned

# Référencer les secrets depuis Key Vault
az containerapp secret set \
  --name content-gateway \
  --resource-group <rg_name> \
  --secrets \
    client-secret=keyvaultref:<keyvault_uri>/secrets/client-secret,identityref:system \
    hmac-secret=keyvaultref:<keyvault_uri>/secrets/hmac-secret,identityref:system
```

---

## Structure des fichiers

```text
content-gateway/
├── Dockerfile             # Image basée sur envoyproxy/envoy:v1.37-latest + gettext
├── docker-entrypoint.sh   # Substitue TENANT_ID et CLIENT_ID via envsubst puis lance Envoy
├── envoy.yaml             # Template de configuration Envoy (routage, auth, RBAC)
└── README.md              # Ce fichier
```

## Références

- [Envoy Proxy Documentation](https://www.envoyproxy.io/docs/envoy/v1.37.0/)
- [Envoy OAuth2 Filter](https://www.envoyproxy.io/docs/envoy/v1.37.0/configuration/http/http_filters/oauth2_filter)
- [Envoy JWT Authentication](https://www.envoyproxy.io/docs/envoy/v1.37.0/configuration/http/http_filters/jwt_authn_filter)
- [Envoy RBAC Filter](https://www.envoyproxy.io/docs/envoy/v1.37.0/configuration/http/http_filters/rbac_filter)
- [Azure Container Apps Documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Microsoft Entra ID App Registration](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app)
