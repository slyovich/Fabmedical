const { ServiceBusClient } = require('@azure/service-bus');

describe('notificationpublisher -> consumer1 sqlFilter', () => {
  let connectionString;
  let serviceBusClient;
  let topicSender;
  let subscriptionReceiver;

  async function drainSubscription() {
    while (true) {
      const received = await subscriptionReceiver.receiveMessages(50, { maxWaitTimeInMs: 1500 });
      if (received.length === 0) {
        break;
      }

      for (const message of received) {
        await subscriptionReceiver.completeMessage(message);
      }
    }
  }

  beforeAll(async () => {
    connectionString = process.env.SERVICEBUS_CONNECTION;

    serviceBusClient = new ServiceBusClient(connectionString);
    topicSender = serviceBusClient.createSender('notificationpublisher');
    subscriptionReceiver = serviceBusClient.createReceiver('notificationpublisher', 'consumer1');

    await drainSubscription();
  });

  afterAll(async () => {
    if (subscriptionReceiver) {
      await subscriptionReceiver.close();
    }
    if (topicSender) {
      await topicSender.close();
    }
    if (serviceBusClient) {
      await serviceBusClient.close();
    }
  });

  test('only messages with label error are available in consumer1 subscription', async () => {
    const testRunId = `run-${Date.now()}`;

    await topicSender.sendMessages([
      {
        body: { testRunId, level: 'error' },
        subject: 'error',
        messageId: `${testRunId}-error`,
        applicationProperties: { testRunId, label: 'error' }
      },
      {
        body: { testRunId, level: 'info' },
        subject: 'info',
        messageId: `${testRunId}-info`,
        applicationProperties: { testRunId, label: 'info' }
      }
    ]);

    const matchingMessages = [];
    const deadline = Date.now() + 30000;

    while (Date.now() < deadline) {
      const batch = await subscriptionReceiver.receiveMessages(20, { maxWaitTimeInMs: 3000 });

      for (const msg of batch) {
        await subscriptionReceiver.completeMessage(msg);

        if (msg.applicationProperties?.testRunId === testRunId) {
          matchingMessages.push(msg);
        }
      }

      const hasExpectedError = matchingMessages.some((msg) => msg.subject === 'error');
      const hasUnexpectedInfo = matchingMessages.some((msg) => msg.subject === 'info');

      if (hasExpectedError && !hasUnexpectedInfo) {
        break;
      }
    }

    expect(matchingMessages).toHaveLength(1);
    expect(matchingMessages[0].subject).toBe('error');
  });
});
