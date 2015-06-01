
module.exports = {

    host: "localhost",
    port: 3000,
    //debugEndpoint: "/debug/consol",  // endpoint to be used in the TV module

    publicUri: "http://localhost",  // the domain name
    publicPort: 3000,  // probably 80

    // the default language is the first in the array below
    allowedLanguages: ["pt", "en"],


    hapi: {

        // options for the Hapi.Server object (to be used in the main index.js)
        server: {
            connections: {
                router: {
                    isCaseSensitive: false,
                    stripTrailingSlash: true
                }            
            }
        },

        // options for the views (to be used in the main index.js)
        views: {
            path: global.rootPath + 'server/views',
            engines: {
                "html": require('hapi-nunjucks')
            }
        },

        auth: {
            mode: "try"
        },

        // documentation: https://github.com/hapijs/joi#validatevalue-schema-options-callback
        joi: {
            abortEarly: false,  // returns all the errors found (does not stop on the first error)
            allowUnknown: true, // allows object to contain unknown keys (they can be deleted or not - see the stripUnknown options)
            stripUnknown: false,  // delete unknown keys
            convert: true
    /*


            convert: ...
            skipFunctions: ...
            stripUnknown: ...
            language: ...
            presence: ...
            context: ...
    */
        },

    },

    apiRoutePrefix: {
        v1: "/api/v1"
    },

    email: {
        // should be redefined in some other configuration file (that should be present in .gitignore)
        mandrill: {
            host: "smtp.mandrillapp.com",
            port: 587,
            smtpUsername: "x@y.com",
            apiKey: "123456789"
        },

        fromEmail: "paulovieira@gmail.com",
        fromName: "CLIMA-MADEIRA",

        subject: "Password recovery",
        body: "To recover your password, please click the following link: "
    },

    db: {

        // should be redefined in some other configuration file (that should be present in .gitignore)
        postgres: {
            host: "127.0.0.1",
            database: "db_name",
            username: "db_username",
            password: "db_password",

            getConnectionString: function(){
                return "postgres://" +
                        this.username + ":" +
                        this.password + "@" +
                        this.host + "/" +
                        this.database;
            }
        },
    },

    uploads: {
        physicalPath: "/data/uploads/public/",
        logicalPath: "/uploads/public/"
    },

    availableRoutes: [

        {
            level1: "",
            level2: "",
            level3: ""
        },

        // ----------------------
        
        {
            level1: "introducao",
            level2: "mensagem",
            level3: ""
        },
        {
            level1: "introducao",
            level2: "metodologia",
            level3: ""
        },
        {
            level1: "introducao",
            level2: "workshops",
            level3: ""
        },            {
            level1: "introducao",
            level2: "equipa",
            level3: ""
        },

        // ----------------------
        
        {
            level1: "sumario-executivo",
            level2: "",
            level3: ""
        },

        // ----------------------
        {
            level1: "sectores",
            level2: "clima",
            level3: ""
        },            
        {
            level1: "sectores",
            level2: "clima",
            level3: "forest-growth"
        },            
        // ----------------------
        {
            level1: "sectores",
            level2: "adaptacao",
            level3: ""
        },
        {
            level1: "sectores",
            level2: "adaptacao",
            level3: "forest-growth"
        },
        // ----------------------
        {
            level1: "sectores",
            level2: "saude",
            level3: ""
        },
        {
            level1: "sectores",
            level2: "saude",
            level3: "forest-growth"
        },
        // ----------------------
        {
            level1: "sectores",
            level2: "turismo",
            level3: ""
        },
        {
            level1: "sectores",
            level2: "turismo",
            level3: "forest-growth"
        },
        // ----------------------
        {
            level1: "sectores",
            level2: "energia",
            level3: ""
        },
        {
            level1: "sectores",
            level2: "energia",
            level3: "forest-growth"
        },
        // ----------------------
        {
            level1: "sectores",
            level2: "biodiversidade",
            level3: ""
        },
        {
            level1: "sectores",
            level2: "biodiversidade",
            level3: "forest-growth" 
        },
        // ----------------------
        {
            level1: "sectores",
            level2: "risco-hidrologico",
            level3: ""
        },
        {
            level1: "sectores",
            level2: "risco-hidrologico",
            level3: "forest-growth"
        },
        // ----------------------
        {
            level1: "sectores",
            level2: "qualidade-disponibilidade-agua",
            level3: ""
        },
        {
            level1: "sectores",
            level2: "qualidade-disponibilidade-agua",
            level3: "forest-growth"
        },
        // ----------------------
        {
            level1: "sectores",
            level2: "agricultura-florestas",
            level3: ""
        },
        {
            level1: "sectores",
            level2: "agricultura-florestas",
            level3: "forest-growth"
        },

        // ----------------------

        // ----------------------
        
        {
            level1: "cartografia",
            level2: "",
            level3: ""
        },

        // ----------------------
        
        {
            level1: "estrategia-adaptacao",
            level2: "",
            level3: ""
        }

    ]


};
