var Config = require('config');
var Hoek = require('hoek');
var Boom = require('boom');
var Joi = require('joi');
var _s = require('underscore.string');

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
	},

	// logStack: function(callsiteObj){

 //        var output = '\x1b[36m' + (callsiteObj.getFunctionName() || 'anonymous') + '()\x1b[90m in '
 //                    + callsiteObj.getFileName() + ":" + 
 //                    + callsiteObj.getLineNumber();

 //        server.log(["stack"], output);

 //        return output;
 //    },

	validations: {
		validateIds: function(value, options, next){

			value.ids = _s.trim(value.ids, ",").split(",");

			var idSchema = Joi.number().integer().min(0);

			// must be an objet like this: { ids: [3,5,7] }
			var schema = Joi.object().keys({
			    ids: Joi.array().unique().items(idSchema)
			});

			var validation = Joi.validate(value, schema, Config.get('hapi.joi'));

			if(validation.error){  return next(validation.error);  }

			// at this point validation.value is on object of the form { ids: [3] } or { ids: [3,5] }; we want it to be
			// { ids: [{id: 3}, {id: 5}] }  (then we simply have pass the [{id: 3}, {id: 5}] to the postgres function)

			validation.value.ids = validation.value.ids.map(function(id){
				return { "id": id };
			});

			return next(undefined, validation.value);
		},
	}


}