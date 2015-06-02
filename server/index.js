// Load modulesyyy

var Hapi = require('hapi');
var Db = require('../database');
var Utils = require('./utils');
/*
var HomeRoute = require('./routes/home');
var GeneralPageRoute = require('./routes/general-page');
var CatchAllRoute = require('./routes/catch-all');

var ClimaAuthCookie = require('../../clima-auth-cookie/lib/index.js');
*/



/*
*/
var ClimaApiTexts = require('../../clima-api-texts');

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
    // plugins.push(HomeRoute);
    // plugins.push(GeneralPageRoute);
    // plugins.push(CatchAllRoute);

    // authentication
    //plugins.push(ClimaAuthCookie);

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

    plugins.push({
        register: ClimaApiTexts,
        options: {
            db: Db,
            utils: Utils
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


    server.method([
        // {
        //     name: "abortIfNotAuhtenticated"
        //     method: function(err, result){

        //     },
        //     options: {

        //     }
        // }
    ]);


    // make sure we always have a "credentials" object on request.auth
    server.ext("onPostAuth", function(request, reply){
        request.auth.credentials = request.auth.credentials || {};
        return reply.continue();
    });

    // api
    // server.register(
    //     {
    //         register: ClimaApiTexts,
    //         options: {
    //             db: DB
    //         }
    //     },
    //     {
    //         routes: {
    //             prefix: "/api"
    //         }
    //     },
    //     function (err) {
    //         if (err) {
    //             return next(err);
    //         }
    //     }
    // );

};

