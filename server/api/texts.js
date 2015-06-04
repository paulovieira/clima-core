var Boom = require('boom');
var Joi = require('joi');
var Config = require('config');
var Utils = require('../utils');
var Db = require('../../database');
var _ = require("underscore");


var dummy1 = function(){
	console.log("dummy1");
};

var dummy2 = function(){
	console.log("dummy2");
};

var internals = {

    validatePayloadForCreate: function(value, options, next) {

        // if (_.isObject(value) && !_.isArray(value)) {
        //     value = [value];
        // }


        var schemaCreate = Joi.object().keys({

            id: Joi.number().integer().min(0),

            //tags: Joi.string().allow("").regex(/^[-\w\s]+(?:,[-\w\s]+)*$/),
            //tags: Joi.alternatives().try(Joi.string().allow("").regex(/^[-\w\s]+(?:,[-\w\s]+)*$/), Joi.string().allow("")),

            tags: Joi.string().allow(""),

            contents: Joi.object().keys({
                pt: Joi.string().allow(""),
                en: Joi.string().allow("")
            }).required(),

            description: Joi.object().keys({
                pt: Joi.string().allow(""),
                en: Joi.string().allow("")
            }),

            properties: Joi.object(),

            active: Joi.boolean()

        });

        return Utils.validatePayload(value, options, next, schemaCreate);
    },

    transformMap: {

        // a) properties to be maintained
        "id": "id",
        "tags": "tags",
        "contents": "contents",
        "lastUpdated": "last_updated",

        // b) new properties (move properties from the nested object to the top object)
        // NOTE: this is used to make the server-side templates lighter
        //          "pt": "contents.pt",
        //          "en": "contents.en",

        // c) changed properties (some fields from authorData, such as pwHash, will be deleted)

        // the changeCaseKeys is only changinf the 1st level keys
        "authorData.id": "author_data.id",
        "authorData.firstName": "author_data.first_name",
        "authorData.lastName": "author_data.last_name",
        "authorData.email": "author_data.email",

        // d) deleted properties: "contentsDesc", "authorId", "active"
    }
};


module.exports = {

    readAll: {
        handler: function(request, reply, server, options) {
            return Db
                .func('texts_read')
                .then(function(data) {
                    var response = Utils.transformArray(data, internals.transformMap);
                    return reply(response);
                })
                .catch(function(errMsg) {
                    return reply(Boom.badImplementation(errMsg));
                });
        },

        config: {
            pre: [
                Utils.abortIfNotAuthenticated
            ],

            auth: Config.get('hapi.auth')
        }
    },

    read: {
        handler: function(request, reply, server, options) {
            return Db
                .func('texts_read', JSON.stringify(request.params.ids))
                .then(function(data) {

                    if (data.length === 0) {
                        return reply(Boom.notFound("The resource does not exist."));
                    }

                    var response = Utils.transformArray(data, internals.transformMap);
                    return reply(response);
                })
                .catch(function(errMsg) {
                    return reply(Boom.badImplementation(errMsg));
                });
        },

        config: {
            validate: {
                params: Utils.validateIds
            },

            pre: [
                Utils.abortIfNotAuthenticated
            ],

            auth: Config.get('hapi.auth')
        }
    },

    create: {
        handler: function(request, reply, server, options) {

            request.payload.forEach(function(obj) {
                obj["author_id"] = request.auth.credentials.id;
            });

            return Db
                .func('texts_create', JSON.stringify(request.payload))
                .then(function(createdData) {

                    if (createdData.length === 0) {
                        return reply(Boom.notFound("The resource could not be created."));
                    }

                    var createdDataIds = createdData.map(function(obj){ 
                    	return { id: obj.id }; 
                    });

                    console.log("createdDataIds: ", createdDataIds);
                    return Db.func("texts_read", JSON.stringify(createdDataIds));
                })
                .then(function(data){

                    if (data.length === 0) {
                        return reply(Boom.notFound("The resource could not be created."));
                    }

                    var response = Utils.transformArray(data, internals.transformMap);
                    return reply(response);
                })
                .catch(function(errMsg) {
                    return reply(Boom.badImplementation(errMsg));
                });
        },

        config: {

            validate: {
                payload: internals.validatePayloadForCreate
            },

            pre: [
                Utils.abortIfNotAuthenticated,
                Utils.extractTags
            ],

            auth: Config.get('hapi.auth'),

        }
    },

    delete: {
        handler: function(request, reply, server, options) {
            return Db
                .func('texts_delete', JSON.stringify(request.params.ids))
                .then(function(data) {

                    if (data.length === 0) {
                        return reply(Boom.notFound("The resource does not exist."));
                    }

                    return reply(data);
                })
                .catch(function(errMsg) {
                    return reply(Boom.badImplementation(errMsg));
                });
        },

        config: {

            validate: {
                params: Utils.validateIds
            },

            pre: [
                Utils.abortIfNotAuthenticated
            ],

            auth: Config.get('hapi.auth'),
        }
    },

}




/*

CURL TESTS
==============


curl http://127.0.0.1:3000/api/v1/texts  \
    --request GET

curl http://127.0.0.1:3000/api/v1/texts/1  \
    --request GET

curl http://127.0.0.1:3000/api/v1/texts/1,2  \
    --request GET


-------------------------------


curl  http://127.0.0.1:3000/api/v1/texts  \
    --request POST  \
    --header "Content-Type: application/json"  \
    --data '{ "tags": "aaa,ccc ggg", "contents": { "pt": "abc-pt", "en": "abc-en"} }' 


curl  http://127.0.0.1:3000/api/v1/texts  \
    --request POST  \
    --header "Content-Type: application/json"  \
    --data '[{ "tags": "aaa,ccc ggg", "contents": { "pt": "abc-pt", "en": "abc-en"} }, { "tags": "xx,yy", "contents": { "pt": "xyz-pt", "en": "xyz-en"} }]' 




curl  http://127.0.0.1:3000/api/v1/texts  \
    --request POST  \
    --header "Content-Type: application/json"  \
    --data '[{ "tags": "aaa,ccc ggg", "contents": { "pt": "abc-pt", "en": "abc-en"} }, { "tags": "aaa", "contents": { "pt": "xyz-pt", "en": "xyz-en"} }]' 


curl  http://127.0.0.1:3000/api/v1/texts  \
    --request POST  \
    --header "Content-Type: application/json"  \
    --data '[{ "tags": "aaa,ccc ggg", "contents": { "pt": "xyz-pt", "en": "xyz-en"} }]' 


-------------------------------


curl http://127.0.0.1:3000/api/v1/texts/1001   \
    --request PUT
    --header "Content-Type: application/json"  \
    --data '{"id": 1001, "tags": "aaa,ccc xxx", "contents": { "pt": "xyz-pt", "en": "xyz-en"}, "description": { "pt": "desc-pt", "en": "desc-en"} }' 


-------------------------------


curl http://127.0.0.1:3000/api/v1/texts/54  \
    --request DELETE



*/
