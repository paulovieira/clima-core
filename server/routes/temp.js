
var internals = {

};

exports.register = function(server, options, next){

    server.route({
        method: "GET",
        path: "/",
        handler: function(request, reply) {
            return reply.redirect("/temp");
        },
        config: {
        }
    });

    return next();
};


exports.register.attributes = {
    name: 'index-route'
};
