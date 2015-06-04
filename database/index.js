var pgpLib = require('pg-promise'),
    PgMonitor = require("pg-monitor"),
    config = require("config"),
    Q = require("q");

var pgpOptions = {
    promiseLib: Q
}

PgMonitor.attach(pgpOptions, null, true);

var pgp = pgpLib(pgpOptions); 


var connectionOptions = {
    host: config.get("db.postgres.host"),
    port: 5432,
    user: config.get("db.postgres.username"),
    password: config.get("db.postgres.password"),
    database: config.get("db.postgres.database"),
    //pgFormatting: true
};

// db will be the exported object
var db = pgp(connectionOptions);

db.queryResult = {
    one: 1,     // single-row result is expected;
    many: 2,    // multi-row result is expected;
    none: 4,    // no rows expected;
    any: 6      // (default) = many|none = any result.
};

db.as = pgp.as;

db.end = function(){
    pgp.end();
    console.log("Released all connections. Goodbye!");
};

module.exports = db;
