const { MongoClient } = require('mongodb');

const COLLECTION_NAME = 'notifications';
let mongoClientPromise;

function getMongoClient() {
  if (!mongoClientPromise) {
    const connectionString = process.env.MONGODB_CONNECTION;
    if (!connectionString) {
      throw new Error('MONGODB_CONNECTION environment variable is not set');
    }

    // Reuse a single client across warm invocations.
    const client = new MongoClient(connectionString);
    mongoClientPromise = client.connect();
  }

  return mongoClientPromise;
}

module.exports = async function (context, mySbMsg) {
  context.log('Message received from queue notifications:', mySbMsg);

  const client = await getMongoClient();
  const db = client.db();

  await db.collection(COLLECTION_NAME).insertOne(mySbMsg);

  context.log(`Message stored in MongoDB collection ${COLLECTION_NAME}`);
};
