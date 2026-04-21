const mongoose = require('mongoose'),
    Schema = mongoose.Schema;

const NotificationSchema = new Schema({
    _id: {
        type: String
    },
    message: {
        type: String
    },
    datetime: {
        type: Date
    },
    publisher: {
        type: String
    },
    type: {
        type: String
    }
});

module.exports = mongoose.model('Notification', NotificationSchema);