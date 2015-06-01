
/*

	1. READ

*/


-- NOTE: we explicitely execute a DROP FUNCTION (instead of CREATE OR REPLACE) because the replacement will not work if the output changes; by calling DROP wemake sure the function definition will really be updated

DROP FUNCTION IF EXISTS config_read(json);

CREATE FUNCTION config_read(options json DEFAULT '[{}]')

-- return table using the definition of the config table
RETURNS TABLE(
	id          INT,
	config_data JSONB
)
AS
$BODY$

DECLARE
	options_row json;
	command text;
	number_conditions INT;

	-- fields to be used in WHERE clause
	id INT;
	config_data_key TEXT;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(options) = 'object'::text THEN
	options = ('[' || options::text ||  ']')::json;
END IF;


FOR options_row IN ( select json_array_elements(options) ) LOOP

	command := 'SELECT * FROM config ';
			
	-- extract values to be (optionally) used in the WHERE clause
	SELECT json_extract_path_text(options_row, 'id')    INTO id;
	SELECT json_extract_path_text(options_row, 'config_data_key')  INTO config_data_key;

	number_conditions := 0;
	
	-- criteria: id
	IF id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' id = %L', id);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: config_data_key
	IF config_data_key IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' config_data ? %L', config_data_key);
		number_conditions := number_conditions + 1;
	END IF;

	
	command := command || ' ORDER BY id DESC;';

	RETURN QUERY EXECUTE command;

END LOOP;
		
RETURN;
END;
$BODY$
LANGUAGE plpgsql;




/*

select * from config

select * from  config_read('[{}]');

select * from  config_read('[{"config_data_key": "adminEmail"} ]');

select * from  config_read('[{"config_data_key": "adminEmail"}, {"config_data_key": "publicUrl"}]');


*/




/*

	2. CREATE

*/

DROP FUNCTION IF EXISTS config_create(json, json);

CREATE FUNCTION config_create(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF config AS
$BODY$
DECLARE
	new_row config%ROWTYPE;
	input_row config%ROWTYPE;
	current_row config%ROWTYPE;
	new_id INT;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::config, input_data)) LOOP

	SELECT input_row.id INTO new_id;
	IF new_id IS NULL OR NOT EXISTS (SELECT * FROM config WHERE id = new_id) THEN
		INSERT INTO config(
			id,
			config_data
			)
		VALUES (
			COALESCE(new_id, nextval(pg_get_serial_sequence('config', 'id'))),
			input_row.config_data
			)
		RETURNING 
			*
		INTO STRICT 
			new_row;
	
		RETURN NEXT new_row;
	ELSE

		current_row.id = new_id;
		current_row.config_data = '"WARNING: a row with the given id exists already present. Data will not be inserted."';

		RAISE WARNING 'A row with the given id exists already present. Data will not be inserted (id=%)', current_row.id;

		RETURN NEXT current_row;

	END IF;

END LOOP;

RETURN;
END;
$BODY$
LANGUAGE plpgsql;

/*
select * from config order by id desc

select * from config_create('[
	{"config_data": {"publicUrl": "http://xxx.com"}}
]');


select * from config_create('[
	{"config_data": {"adminEmail": "paulo@gmail.com"}},
	{"config_data": {"noRowsForInitialData": 1000 }}
]');



*/




/*

	3. UPDATE

*/

DROP FUNCTION IF EXISTS config_update(json, json);

CREATE FUNCTION config_update(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF config AS
$$
DECLARE
	updated_row config%ROWTYPE;
	input_row config%ROWTYPE;
	command text;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::config, input_data)) LOOP

	-- generate a dynamic command: first the base query
	command := 'UPDATE config SET ';

	-- then add (cumulatively) the fields to be updated; those fields must be present in the input_data json;
	IF input_row.config_data IS NOT NULL THEN
		command = format(command || 'config_data = %L, ', input_row.config_data);
	END IF;

	-- remove the comma and space from the last if
	command = left(command, -2);
	command = format(command || ' WHERE id = %L RETURNING *;', input_row.id);

	--RAISE NOTICE 'Dynamic command: %', command;

	EXECUTE 
		command

	INTO STRICT
		updated_row;


	RETURN NEXT 
		updated_row;
END LOOP;

RETURN;
END;
$$
LANGUAGE plpgsql;


/*

select * from config_update('[
	{"id": 5, "config_data": {"publicUrl": "http://yyy.com"} }
]');



*/





/*

	4. DELETE

*/

DROP FUNCTION IF EXISTS config_delete(json);

CREATE FUNCTION config_delete(options json DEFAULT '[{}]')
RETURNS TABLE(deleted_id int) AS
$$
DECLARE
	deleted_row config%ROWTYPE;
	options_row JSON;

	-- fields to be used in WHERE clause
	id_to_delete INT;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(options) = 'object'::text THEN
	options = ('[' || options::text ||  ']')::json;
END IF;


FOR options_row IN ( select json_array_elements(options) ) LOOP

	-- extract values to be (optionally) used in the WHERE clause
	SELECT json_extract_path_text(options_row, 'id') INTO id_to_delete;
	
	IF id_to_delete IS NOT NULL THEN
		DELETE FROM config
		WHERE id = id_to_delete
		RETURNING *
		INTO deleted_row;

		deleted_id   := deleted_row.id;

		IF deleted_id IS NOT NULL THEN
			RETURN NEXT;
		END IF;
	END IF;
		
END LOOP;

RETURN;
END;
$$
LANGUAGE plpgsql;


/*

select * from config order by id desc;
select * from config_delete('[{"id": 3}]');
*/



