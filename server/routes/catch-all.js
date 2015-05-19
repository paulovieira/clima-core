
var internals = {

};

exports.register = function(server, options, next){

    server.route({
        method: "GET",
        path: "/{anyPath*}",
        handler: function(request, reply) {
            return reply({"ko": "404 (should return the 404 view)"});
        },
        config: {
        }
    });

    return next();
};


exports.register.attributes = {
    name: 'catch-all-route'
};



