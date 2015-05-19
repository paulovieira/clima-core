
var internals = {};

exports.register = function(server, options, next){

    server.route({
        method: "GET",
        path: "/{level1}",
        handler: internals.handler,
        config: {
        }
    });

    server.route({
        method: "GET",
        path: "/{level1}/{level2}",
        handler: internals.handler,
        config: {
        }
    });

    server.route({
        method: "GET",
        path: "/{level1}/{level2}/{level3}",
        handler: internals.handler,
        config: {
        }
    });

    server.route({
        method: "GET",
        path: "/{level1}/{level2}/{level3}/{level4}",
        handler: internals.handler,
        config: {
        }
    });

    server.route({
        method: "GET",
        path: "/{level1}/{level2}/{level3}/{level4}/{level5}",
        handler: internals.handler,
        config: {
        }
    });

    return next();
};


exports.register.attributes = {
    name: 'general-page-route'
};

internals.handler = function(request, reply) {
debugger;
//        console.log(utils.logHandlerInfo(request));
    debugger;
//console.log("user-agent:", request.plugins.scooter.toJSON());
//request.log(['databasex', 'read'], "this is the message");
//request.log(['databasex', 'read'], "this is the message2");


    request.params.level1 = request.params.level1 || "";
    request.params.level2 = request.params.level2 || "";
    request.params.level3 = request.params.level3 || "";
    request.params.level4 = request.params.level4 || "";
    request.params.level5 = request.params.level5 || "";

//        var viewFile = utils.getView(request.params);

    // if the combination of the level params is not recognized (that is, not present in the availableRoutes
    // array in config/default.js), the empty string will be returned

    // if(viewFile===""){
    //     return reply.redirect("/" + request.params.lang + "/404");
    // }

    var context = {
        urlParam1: request.params.level1,
        urlParam2: request.params.level2,
        urlParam3: request.params.level3,
        urlParam4: request.params.level4,
        urlParam5: request.params.level5,
//            urlWithoutLang: utils.getUrlWithoutLang(request.params),
//            auth: request.auth,
    };

    // add the data available in request.pre that has been treated and ready to be used
    // in the nunjucks template: texts, textArray, files, etc
    for(var key in request.pre){
        if(request.pre.hasOwnProperty(key)){
            context[key] = request.pre[key];
        }
    }

    return reply(context);

    return reply.view(viewFile, {
        ctx: context
    });
};

