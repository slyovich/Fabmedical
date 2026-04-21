# content-function

Azure Function Node.js avec un déclencheur Service Bus.

## Fonction

- Trigger: Service Bus queue trigger
- Queue: `notifications`
- Connection setting: `SERVICEBUS_CONNECTION`

Le code de la fonction est dans `notifications/index.js` et la liaison est définie dans `notifications/function.json`.

## Configuration locale

Renseigner la chaîne de connexion Service Bus et MongoDB dans `local.settings.json`:

```json
{
  "Values": {
    "SERVICEBUS_CONNECTION": "<votre-chaine-connexion-service-bus>",
    "MONGODB_CONNECTION": "mongodb://localhost:27017/contentdb"
  }
}
```

## Lancement local

Prérequis: Azure Functions Core Tools installé (`func`).

```bash
npm install
npm start
```
