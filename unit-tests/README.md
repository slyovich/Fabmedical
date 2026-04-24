# Service Bus integration tests

Cette suite valide le comportement du `SqlFilter` de la souscription `consumer1` du topic `notificationpublisher`.

Les tests:

- utilisent l'image `mcr.microsoft.com/azure-messaging/servicebus-emulator:latest`
- montent la configuration existante via `.devcontainer/servicebus-config.json`
- envoient des messages dans le topic
- vérifient que seuls les messages `label=error` sont disponibles dans la souscription

## Prerequis

- Docker + Docker Compose
- Node.js 20+

## Execution locale

Depuis la racine du repo:

```bash
npm --prefix unit-tests install
npm --prefix unit-tests run test:local
```

Cas 1: vous etes dans le Dev Container

- Le service `servicebus-emulator` est deja demarre par `runServices`.
- `test:local` suffit.

Cas 2: vous lancez depuis l'hote (hors Dev Container)

```bash
npm --prefix unit-tests run test:host
```

## Execution CI Linux

Le workflow GitHub Actions [.github/workflows/unit-tests.yml](../.github/workflows/unit-tests.yml) execute la meme suite sur `ubuntu-latest`.

Le workflow:

- demarre `unit-tests/docker-compose.test.yml`
- execute `npm run test:ci --prefix unit-tests`
- arrete et supprime les conteneurs ensuite

Commande de test utilisee en CI:

```bash
npm run test:ci --prefix unit-tests
```
