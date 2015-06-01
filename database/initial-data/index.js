var Q = require("q");
var fs = require("fs");
var Path = require('path');
var stripJsonComments = require("strip-json-comments");
var jsonFormat = require('json-format');
var Bcrypt = require("bcrypt");
var _ = require("underscore");
var changeCase = require("change-case-keys");


var internals = {};

internals.readFile = function(relativePath){
	var array, dataPath = Path.join(__dirname, relativePath);
	try{
		array = JSON.parse(stripJsonComments(fs.readFileSync(dataPath, "utf-8")));	
	} 
	catch(err){
		console.log("Error parsing this file: " + dataPath);
		throw err;
	}

 	return array
}

internals.stringify = function(array){
	changeCase(array, "underscored", 2);
	return JSON.stringify(array);
}

module.exports = {

	initialize: function(db){
		this.db = db;
		this.argv = process.argv.slice(2);

		// if this.argv is undefined, the insertion of data will proceed for all the methods
		if(this.argv.length === 0){ 
			this.argv = undefined;
		}

		var deferred = Q.defer();
		deferred.resolve();

		return deferred.promise;
	},

	config: function(){
		if(this.argv && this.argv.indexOf("config")==-1){ return; }

		var configArray = internals.readFile("./config.json");

		var promise = this.db.func("config_create", internals.stringify(configArray))
					.then(function(resp){
						console.log("config table has been populated:\n\n", jsonFormat(resp));
						return resp;
					})

		return promise;
	},

	users: function(){
		if(this.argv && this.argv.indexOf("users")==-1){ return; }

		var usersArray = internals.readFile("./users.json");

		usersArray.forEach(function(obj){
			if(!obj.pwHash){ throw new Error("missing password"); }

			obj.pwHash = Bcrypt.hashSync(obj.pwHash, 10);
		});

		var promise = this.db.func("users_create", internals.stringify(usersArray))
					.then(function(resp){
						console.log("users table has been populated:\n\n", jsonFormat(resp));
						return resp;
					})

		return promise;
	},

	groups: function(){
		if(this.argv && this.argv.indexOf("groups")==-1){ return; }

		var groupsArray = internals.readFile("./groups.json");

		var promise = this.db.func("groups_create", internals.stringify(groupsArray))
					.then(function(resp){
						console.log("groups table has been populated:\n\n", jsonFormat(resp));
						return resp;
					})

		return promise;
	},

	users_groups: function(){
		if(this.argv && this.argv.indexOf("users-groups")==-1){ return; }

		var usersGroupsArray = internals.readFile("./users-groups.json");

		var emailsCriteria = _.chain(usersGroupsArray)
							.pluck("email")
							.uniq()
							.map(function(email){
								return { "email": email}
							})
							.value();

		// first we make a query to find the ids of the users with the given email
		var self = this;
		var promise = this.db.func("users_read", JSON.stringify(emailsCriteria))
					.then(function(users){

						// now insert the "userId" property for each userGroup obj
			            usersGroupsArray.forEach(function(userGroup) {
			                var user = _.findWhere(users, {email: userGroup.email});

			                // don't proceed if some email address is invalid
			                if (!user) {
		                    	throw new Error("there is no user with the given email address: " + JSON.stringify(text))
			                }

			                userGroup.userId = user.id;
			            });

			            // finally, insert the data
						return self.db.func("users_groups_create", internals.stringify(usersGroupsArray))
					})
					.then(function(resp){
						console.log("users_groups table has been populated:\n\n", jsonFormat(resp));
						return resp;
					})


		return promise;
	},

	texts: function(){
		if(this.argv && this.argv.indexOf("texts")==-1){ return; }

		var textsArray = internals.readFile("./texts.json");

		var emailsCriteria = _.chain(textsArray)
							.pluck("email")
							.uniq()
							.map(function(email){
								return { "email": email}
							})
							.value();

		// first we make a query to find the ids of the users with the given email
		var self = this;
		var promise = this.db.func("users_read", JSON.stringify(emailsCriteria))
					.then(function(users){

						// now insert the "authorId" property for each text obj
			            textsArray.forEach(function(text) {
			                var user = _.findWhere(users, {email: text.author_email});

			                // don't proceed if some email address is invalid
			                if (!user) {
		                    	throw new Error("there is no user with the given email address: " + JSON.stringify(text))
			                }

			                text.authorId = user.id;
			            });

			            // finally, insert the data
						return self.db.func("texts_create", internals.stringify(textsArray))
					})
					.then(function(resp){
						console.log("texts table has been populated:\n\n", jsonFormat(resp));
						return resp;
					})

		return promise;

	},

	// NOTE: for files and maps we give the user id explicitely, instead of the email address
	files: function(){
		if(this.argv && this.argv.indexOf("files")==-1){ return; }

		var filesArray = internals.readFile("./files.json");

		var promise = this.db.func("files_create", internals.stringify(filesArray))
					.then(function(resp){
						console.log("files table has been populated:\n\n", jsonFormat(resp));
						return resp;
					})

		return promise;
	},

	maps: function(){
		if(this.argv && this.argv.indexOf("maps")==-1){ return; }

		var mapsArray = internals.readFile("./maps.json");

		var promise = this.db.func("maps_create", internals.stringify(mapsArray))
					.then(function(resp){
						console.log("maps table has been populated:\n\n", jsonFormat(resp));
						return resp;
					})

		return promise;
	}

}
