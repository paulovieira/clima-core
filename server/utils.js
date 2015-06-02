var Config = require('config');
var Hoek = require('hoek');
var Boom = require('boom');

module.exports = {


	abortIfNotAuthenticated: function(request, reply){
		console.log("pre: abortIfNotAuthenticated");

		// with NODE_ENV=dev-no-auth, all routes have "config: false"
	    //console.log("route settings: ", JSON.stringify(request.route.settings.auth));
    	if(request.route.settings.auth!==false){
	        if(!request.auth.credentials.id){
	            return reply(Boom.unauthorized("To access this resource you must be authenticated."));
	        }
	    }
	    else{
	    	// simulate the login using the first user
	        request.auth.credentials.id        = Config.get('hapi.dummyCredentials.id');
	        request.auth.credentials.firstName = Config.get('hapi.dummyCredentials.firstName');
	        request.auth.credentials.lastName  = Config.get('hapi.dummyCredentials.lastName');
	        request.auth.credentials.isAdmin   = Config.get('hapi.dummyCredentials.isAdmin');
	    }

	    return reply();
	},

	transformArray: function(array, transform){
	    return array.map(function(obj){
	        return Hoek.transform(obj, transform);
	    });
	}


}