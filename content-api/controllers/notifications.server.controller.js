const mongoose = require('mongoose'),
    Notification = mongoose.model('Notification');

exports.list = function(query, callback) {
    console.log("==== Load Notifications ====");
    Notification.find(query).lean().exec(function(err, notificationsList) {
        if (err) {
            callback(err);
        } else {
            notificationsList.sort(function(a, b) {
                return String(b.datetime || '').localeCompare(String(a.datetime || ''));
            });
            callback(null, notificationsList);
        }
    });
};
