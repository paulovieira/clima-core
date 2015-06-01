# Clima Database 

## Introduction 
For every table we have 4 function (relative to 4 fundamental operations)

	- tablename_read(json options)  [options will be used in the WHERE clause]
	- tablename_create(json input_data, json options)  [options should be ignored for now]
	- tablename_update(json input_data, json options)  [options should be ignored for now]
	- tablename_delete(json options)  [options will be used in the WHERE clause]

To interact with the tables using these functions we must use the json format.

For input: the json argument should a string of json (either an object or an array of objects).

For output: all functions return the a json string (an array of objects as well), because that's what the node-postgres module returns. 


## Read data

### Usage

To retrieve data (tablename_read) we send the conditions for the WHERE clause in a json object:

    select * from  tablename_read('[{"id" : 10}]');

This will read the rows where id = 10.

If a json object has 2 or more properties, they will be used with the AND operator:

    select * from  tablename_read('[{"id":1, "email": "paulo@gmail.com"}]');

This will read the rows where id = 10 and email = paulo@gmail.com

We can also send 2 or more objects (we must send an array of objects, even if the array has only 1 object). For each object a new query will be made and the results will be appended:

    select * from  tablename_read('[{"id":10}, {"id":11}]');

This will read the rows with id = 10 and add to the output result set; then will select the rows with id = 11 and add to the results (we should end up with 2 rows).

We can also send arbitrary options:

    select * from  tablename_read('[{"limit":10, "offset": 2}]');
    select * from  tablename_read('[{"email_like": "vieira"}]');
    select * from  tablename_read('[{"id_less_than": 10}]');
    select * from  tablename_read('[{"raw": "u.id < 10"}]');

The function tablename_read must be prepared to use conditions given in properties, that is, they must be recognized in the input options and implemented. Otherwise the those properties will be ignored.

If the options is empty (no properties), no conditions will be used, so all rows will be returned.

    select * from  tablename_read('[{}]');

### Implementation

We use json_array_elements(options) to convert the array of objects into a table (where each row is of type json). Then we loop over the rows, obtaining each json object in the options_row variable (declared previously with type JSON)
```sql
FOR options_row IN ( select json_array_elements(options) ) LOOP
    ...
END LOOP
```

For each object we extract the properties we are interested in:

```sql
FOR options_row IN ( select json_array_elements(options) ) LOOP
    SELECT json_extract_path_text(options_row, 'id')         INTO id;
    SELECT json_extract_path_text(options_row, 'email')      INTO email;
    SELECT json_extract_path_text(options_row, 'email_like') INTO email_like;
END LOOP
```

Then we construct a dynamic query depending on the properties that were given. Usually this means adding conditions to the WHERE clause inside an IF.



## Create data

### Usage

To create data (tablename_create) we send the data for the new rows as an array of json objects

    select * from  tablename_create('[
        {"email": "paulo@gmail.com", "first_name": "paulo"},
        {"email": "ana@gmail.com", "first_name": "ana"}
    ]');

The keys of the properties should match the names of the columns. If not, those properties will be ignored (in particular, if we send extra properties, they will be ignored). 

We can create 2 or more rows in the same call.

The function returns the newly created rows (with all fields, so in particular we get the new ids).

The function has a 2nd argument (options json), but it's optional and is not used at the moment. It can be ignored.

### Implementation

Instead of doing the loop using json_array_elements, we use json_populate_recordset. This function converts the input json (array of objects) into a set of rows of a given type. This way we end up with fields of the correct type:

FOR input_row IN (select * from json_populate_recordset(null::tablename, input_data)) LOOP
    ...
END LOOP


The values of the properties will be available in the fields of input_row (which was declared as table%ROWTYPE), and will be with the correct type. We just have to insert the data:

FOR input_row IN (select * from json_populate_recordset(null::tablename, input_data)) LOOP
    INSERT INTO tablename(email,  first_name)
    VALUES (input_row.email,  input_row.first_name)
END LOOP

If the input json is missing some column from the tablename definition, the corresponding field in input_row will be null. And if the json has some extra/unknown properties, those will be ignored.



## Update data

### Usage

Updating is very similar to creating: we send the data as an array of json objects

    select * from  tablename_update('[
        {"id": 10, "email": "paulo@gmail.com", "first_name": "paulo"},
        {"id": 11, "email": "ana@gmail.com"}
    ]');

The json objects must have an id property (it will used in the WHERE clause of the UPDATE).

The only fields that will be updated are the ones corresponding the properties present in the object (each object can have different properties). The remaining fields will be untouched. If extra/unknown properties are sent, they will be ignored.

The function tablename_update returns the rows that have been updated (all fields of the row).

The function has a 2nd argument (options json), but it's optional and is not used at the moment. It can be ignored.

### Implementation

It is similar to what was done in the tablename_create function. First we convert the input json using json_populate_recordset and loop over the rows. Then we create a dynamic query for updating only the given fields (for each object):

FOR input_row IN (select * from json_populate_recordset(null::table, input_data)) LOOP
    command := 'UPDATE users SET ';
    IF input_row.email IS NOT NULL THEN
        command = format(command || 'email = %L, ', input_row.email);
    END IF;
    ...
    EXECUTE command;

END LOOP

If the input json is missing some column from the tablename definition, the corresponding field in input_row will be null, so it will not be part of the update. 

And if the json has some extra/unknown properties, those will be ignored.

## Delete data

### Usage

The call to tablename_delete is similar to tablename_read: we send an array of objects (options). The properties of each object will be used in the WHERE clause (usually they should have only the id):

select * from tablename_delete('[{"id": 253}, {"id": 255}]');

This call will delete the row with id 253, and then the row with id 255

We can implement more general conditions:

select * from tablename_delete('[{"created_at_less_then": "2014-01-01"}]');

### Implementation

Similar to tableame_read: 
1) convert the json using json_array_elements(options)
2) loop over the rows
3) use json_extract_path_text to get the values of the properties we are interested in (usually the id)
4) execute the DELETE command using the values








LOADING SHAPES

shp2pgsql -I -s 4326  climate-madeira.shp  climate_madeira  |  psql --dbname=test_150111



# update the database

After fetching a new version we probably have to update the db. To do that run database/update_db.js

    node database/update_db.js

This will execute all the sql scripts in the database directory.

## Update of the seed data

The seed data is placed with an id <= 1000 (the data created through the user interface will have an id >= 1001). We might add new seed data, for which we will have to find an id: the max available id that is <= 1000.

When doing the update we cannot delete the existing seed data as it might have been already changed by the users.



