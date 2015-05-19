var pgpLib = require('pg-promise'),
    config = require("config"),
    Q = require("q");


console.log("               db: creating instance");

var pgp = pgpLib({
    promiseLib: Q
}); 

var db = pgp({
    host: config.get("db.postgres.host"),
    port: 5432,
    user: config.get("db.postgres.username"),
    password: config.get("db.postgres.password"),
    database: config.get("db.postgres.database"),
    //pgFormatting: true
});

db.queryResult = {
    one: 1,     // single-row result is expected;
    many: 2,    // multi-row result is expected;
    none: 4,    // no rows expected;
    any: 6      // (default) = many|none = any result.
};


module.exports = db;
