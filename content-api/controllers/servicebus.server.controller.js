'use strict';

const { ServiceBusClient } = require('@azure/service-bus');

/**
 * Publishes a message to Azure Service Bus.
 * Expects a JSON body with: message, datetime, publisher, type.
 * Uses the SERVICEBUS_CONNECTION environment variable for the connection string.
 * The queue name defaults to "messages" and can be overridden via SERVICEBUS_QUEUE_NAME.
 */
exports.publish = async function (req, res) {
    const { message, datetime, publisher, type } = req.body;

    // Validate required fields
    if (!message || !datetime || !publisher || !type) {
        return res.status(400).json({
            error: 'Missing required fields. Expected: message, datetime, publisher, type'
        });
    }

    const connectionString = process.env.SERVICEBUS_CONNECTION;
    if (!connectionString) {
        return res.status(500).json({
            error: 'SERVICEBUS_CONNECTION environment variable is not configured'
        });
    }

    const queueName = process.env.SERVICEBUS_QUEUE_NAME || 'notifications';
    let sbClient;

    try {
        sbClient = new ServiceBusClient(connectionString);
        const sender = sbClient.createSender(queueName);

        await sender.sendMessages({
            body: {
                message,
                datetime,
                publisher,
                type
            },
            contentType: 'application/json'
        });

        await sender.close();

        res.status(200).json({
            status: 'Message published successfully',
            queueName: queueName
        });
    } catch (err) {
        console.error('Error publishing message to Service Bus:', err.message);
        res.status(500).json({
            error: 'Failed to publish message to Service Bus',
            details: err.message
        });
    } finally {
        if (sbClient) {
            await sbClient.close();
        }
    }
};
