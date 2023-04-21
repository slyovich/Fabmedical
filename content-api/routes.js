'use strict';

const appController = require('./controllers/app.server.controller');

const init = function (app) {
    app.get("/sessions", appController.sessionsGet);
    app.get("/speakers", appController.speakersGet);
    app.get("/stats", appController.statsGet);
    app.get("/version", function(req, res) {
        //res.status(200).send(JSON.stringify({version: process.env.BUILD_VERSION || '1.0.0'}));
        res.json({version: process.env.BUILD_VERSION || '1.0.0'});
    });
    app.get("/", function (req, res) {
        res.status(200).send("");
    });
};

module.exports = init;