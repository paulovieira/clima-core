var Config = require('config');
var Hoek = require('hoek');
var Boom = require('boom');
var Joi = require('joi');
var _ = require('underscore');
var _s = require('underscore.string');
var changeCase = require("change-case-keys");

module.exports = {

    // methods to be used in pre-requisites
    abortIfNotAuthenticated: function(request, reply) {
        // with NODE_ENV=dev-no-auth, all routes have "config: false"
        //console.log("route settings: ", JSON.stringify(request.route.settings.auth));
        if (request.route.settings.auth !== false) {
            if (!request.auth.credentials.id) {
                return reply(Boom.unauthorized("To access this resource you must be authenticated."));
            }
        } else {
            // simulate the login using the first user
            request.auth.credentials.id = Config.get('hapi.dummyCredentials.id');
            request.auth.credentials.firstName = Config.get('hapi.dummyCredentials.firstName');
            request.auth.credentials.lastName = Config.get('hapi.dummyCredentials.lastName');
            request.auth.credentials.isAdmin = Config.get('hapi.dummyCredentials.isAdmin');
        }

        return reply();
    },

    abortRequest: function(request, reply) {
        return reply(Boom.unauthorized("To access this resource you must be authenticated."));
    },

    extractTags: function(request, reply) {
        /*
                function createTagsArray(payloadObj, tags) {
                	var tagsArray = [];
                    if (typeof tags === "string") {
                        tagsArray = tags.split(",");
                        for (var i = 0, l = tagsArray.length; i < l; i++) {

                            // slugify returns a cleaned version of the string:
                            // Replaces whitespaces, accentuated, and special characters with a dash
                            tagsArray[i] = _s.slugify(tagsArray[i]);
                        }

                        // if the original tags string is the empty string, we end up with an array with 1 element
                        // (the empty string); we want the empty array instead
                        if (tagsArray.length === 1 && tagsArray[0] === "") {
                            tagsArray = [];
                        }

                        // update the tags property in request.payload
                        payloadObj.tags = tagsArray;
                    }
                };
        */
        var payloadObj, tagsArray = [];

        if (request.payload) {
            if (_.isArray(request.payload)) {
                payloadObj = request.payload[0];
            } else {
                payloadObj = request.payload;
            }

            if (typeof payloadObj.tags === "string") {
                tagsArray = payloadObj.tags.split(",");
                for (var i = 0, l = tagsArray.length; i < l; i++) {

                    // slugify returns a cleaned version of the string:
                    // Replaces whitespaces, accentuated, and special characters with a dash
                    tagsArray[i] = _s.slugify(tagsArray[i]);
                }

                // if the original tags string is the empty string, we end up with an array with 1 element
                // (the empty string); we want the empty array instead
                if (tagsArray.length === 1 && tagsArray[0] === "") {
                    tagsArray = [];
                }

                // update the tags property in request.payload
                payloadObj.tags = tagsArray;
            }
        }

        return reply();
    },


    extractTags: function(request, reply) {

    	// the payload can be an objecr or an array of objects
        if (request.payload) {
            if (_.isArray(request.payload)) {
                for (var i = 0, l = request.payload.length; i < l; i++) {
                    _createTagsArray(request.payload[i]);
                }
            } else {
                _createTagsArray(request.payload);
            }
        }

        return reply();

        // internal helper function; if the passed object has a tags property (string), it will replace that string
        // with an array of strings as follows: "abc, xyz" -> ["abc", "xyz"]
        function _createTagsArray(payloadObj) {
            var tagsArray = [];
            if (typeof payloadObj.tags === "string") {
                tagsArray = payloadObj.tags.split(",");
                for (var i = 0, l = tagsArray.length; i < l; i++) {

                    // slugify returns a cleaned version of the string:
                    // Replaces whitespaces, accentuated, and special characters with a dash
                    tagsArray[i] = _s.slugify(tagsArray[i]);
                }

                // if the original tags string is the empty string, we end up with an array with 1 element
                // (the empty string); we want the empty array instead
                if (tagsArray.length === 1 && tagsArray[0] === "") {
                    tagsArray = [];
                }

                // update the tags property in the object
                payloadObj.tags = tagsArray;
            }
        };

    },

    // general purpose utilities
    transformArray: function(array, transform) {
        return array.map(function(obj) {
            return Hoek.transform(obj, transform);
        });
    },

    logStack: function(server, callsiteObj) {

        var output = '\x1b[36m' + (callsiteObj.getFunctionName() || 'anonymous') + '()\x1b[90m in ' + callsiteObj.getFileName() + ":" +
            +callsiteObj.getLineNumber();

        server.log(["stack"], output);

        return output;
    },



    validateIds: function(value, options, next) {

        value.ids = _s.trim(value.ids, ",").split(",");

        var idSchema = Joi.number().integer().min(0);

        // must be an objet like this: "{ ids: [3,5,7] }""
        var schema = Joi.object().keys({
            ids: Joi.array().unique().items(idSchema)
        });

        var validation = Joi.validate(value, schema, Config.get('hapi.joi'));

        if (validation.error) {
            return next(validation.error);
        }

        // at this point validation.value is on object of the form { ids: [3] } or { ids: [3,5] }; we want it to be
        // { ids: [{id: 3}, {id: 5}] }  (then we simply have pass the [{id: 3}, {id: 5}] to the postgres function)

        validation.value.ids = validation.value.ids.map(function(id) {
            return {
                "id": id
            };
        });

        return next(undefined, validation.value);
    },

    validatePayload: function(value, options, next, schema) {

        if (_.isObject(value) && !_.isArray(value)) {
            value = [value];
        }

        // validate the elements of the array using the given schema
        var validation = Joi.validate(value, Joi.array().items(schema), Config.get('hapi.joi'));

        if (validation.error) {
            return next(validation.error);
        }

        // validateIds was executed before this one; the ids param (if defined) is now an array of objects like this: 
        // { ids: [{ id: 5}, { id: 7}] }
        var ids = options.context.params.ids;
        console.log("confirm that this is an array of objects: ", ids);
        // if the ids param is defined, make sure that the ids in the param and the ids in the payload are consistent
        if (ids) {

            for (var i = 0, l = validation.value.length; i < l; i++) {
                // the id in the URL param and in the payload must be equal and in the same order

                if (ids[i].id !== validation.value[i].id) {
                    return next(Boom.conflict("The ids given in the payload and in the URI must match (including the order)."));
                }
            }
        }

        // update the value that will be available in request.payload when the handler executes;
        // there are 2 differences: a) Joi has coerced the values to the type defined in the schemas;
        // b) the keys will be in underscored case (ready to be used by the postgres functions)
        return next(undefined, changeCase(validation.value, "underscored"));
    }


}
