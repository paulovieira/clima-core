// Load modules

var Hapi = require('hapi');
var DB = require('./db');

var HomeRoute = require('./routes/home');
var GeneralPageRoute = require('./routes/general-page');
var CatchAllRoute = require('./routes/catch-all');

var ClimaAuthCookie = require('../../clima-auth-cookie/lib/index.js');

var ClimaApiTexts = require('../../clima-api-texts/lib/index.js');

var Good = require("good");
var GoodConsole = require("good-console");
//var Version = require('./version');
//var Private = require('./private');


// Declare internals

var internals = {};


exports.init = function (port, next) {

    var server = new Hapi.Server();
    server.connection({ port: port });

    var plugins = [];

    // routes
    plugins.push(HomeRoute);
    plugins.push(GeneralPageRoute);
    plugins.push(CatchAllRoute);

    // authentication
    plugins.push(ClimaAuthCookie);

    plugins.push({
        register: Good,
        options: {
            reporters: [{
                reporter: GoodConsole,
                events: {
                    //ops: "*",
                    response: "*",
                    log: "*",
                    error: "*",
                    request: "*"
                }
            }]
        }
    });

    server.register(plugins, function (err) {

        if (err) {
            return next(err);
        }

        server.start(function (err) {

            return next(err, server);
        });
    });





    // api
    server.register(
        {
            register: ClimaApiTexts,
            options: {
                db: DB
            }
        },
        {
            routes: {
                prefix: "/api"
            }
        },
        function (err) {
            if (err) {
                return next(err);
            }
        }
    );

};