var populate = require("./initial-data");
var db = require("../server/db");

populate.initialize(db)
	.then(function(){
		return populate.config();
	})
	.then(function(){
		return populate.users();
	})
	.then(function(){
		return populate.groups();
	})
	.then(function(){
		return populate.users_groups();
	})
	.then(function(){
		return populate.texts();
	})
	.then(function(){
		return populate.files();
	})
	.then(function(){
		return populate.maps();
	})
	.then(function(){
		console.log("All done!");
	})
	.catch(function(err){
    	console.log(err);
	});