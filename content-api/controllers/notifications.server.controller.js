const mongoose = require('mongoose'),
    Notification = mongoose.model('Notification');

exports.list = function(query, callback) {
    console.log("==== Load Notifications ====");
    Notification.find(query).sort({
        datetime: -1
    }).lean().exec(function(err, notificationsList) {
        if (err) {
            callback(err);
        } else {
            callback(null, notificationsList);
        }
    });
};
