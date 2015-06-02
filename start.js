// Load modules

var Hoek = require('hoek');
var Config = require('config');

var Server = require('./server/index');


// Declare internals

var internals = {
    port: Config.get("port")
};


Server.init(internals.port, function (err, server) {

    Hoek.assert(!err, err);
    console.log('Server started at: ' + server.info.uri);
});
/*
*/