--select * from texts order by id desc;
--delete from texts where id >= 3

/*

	1. READ

A text
	- has one user (author)

We return 
	- all the fields in the texts table (the author_id is one of the fields)
	- a json array of objects relative to all the user that is the author (the array will only have 1 object)
*/


DROP FUNCTION IF EXISTS texts_read(json);

CREATE FUNCTION texts_read(options json DEFAULT '[{}]')

-- return table uses the definition of the texts table + extra data from the join
RETURNS TABLE(
	id INT,
	tags JSONB,
	contents JSONB,
	author_id INT,
	description JSONB,
	properties JSONB,
	active BOOL,	
	last_updated timestamptz,
	author_data JSON)
AS
$BODY$

DECLARE
	options_row json;
	command text;
	number_conditions INT;

	-- fields to be used in WHERE clause
	id INT;
	author_id INT;
	author_email TEXT;
	tags TEXT;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(options) = 'object'::text THEN
	options = ('[' || options::text ||  ']')::json;
END IF;


FOR options_row IN ( select json_array_elements(options) ) LOOP

	command := 'SELECT 
			t.*, 
			(select row_to_json(_dummy_) from (select u.*) as _dummy_) as author_data
		FROM texts t 
		LEFT JOIN users u
		ON t.author_id = u.id';
			
	-- extract values to be (optionally) used in the WHERE clause
	SELECT json_extract_path_text(options_row, 'id')           INTO id;
	SELECT json_extract_path_text(options_row, 'author_id')    INTO author_id;
	SELECT json_extract_path_text(options_row, 'author_email') INTO author_email;
	SELECT json_extract_path_text(options_row, 'tags')          INTO tags;

	number_conditions := 0;

	-- criteria: id
	IF id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' t.id = %L', id);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: author_id
	IF author_id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' t.author_id = %L', author_id);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: author_email
	IF author_email IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' u.email = %L', author_email);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: tags
	IF tags IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' t.tags ?| ARRAY[%L]', tags);
		number_conditions := number_conditions + 1;
	END IF;

	
	command := command || ' ORDER BY t.id;';

	RETURN QUERY EXECUTE command;

END LOOP;
		
RETURN;
END;
$BODY$
LANGUAGE plpgsql;



/*
select * from texts

select * from texts_read('[{}]');
select * from texts_read('[{"tags": "tag1"}]');
select * from  texts_read('[{"email":"paulovieira@gmail.com"}, {"id":"2"}]');
select * from  texts_read('[{"id":"1"}]');

*/




/*

	2. CREATE

*/


DROP FUNCTION IF EXISTS texts_create(json, json);

CREATE FUNCTION texts_create(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF texts AS
$BODY$
DECLARE
	new_row texts%ROWTYPE;
	input_row texts%ROWTYPE;
	current_row texts%ROWTYPE;
	new_id INT;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::texts, input_data)) LOOP

	SELECT input_row.id INTO new_id;

	-- we proceed with the insert in 2 cases: 
	--   a) if the id was not given (in which case we retrieve a new id from the sequence); 
	--   b) if the id was given and there is no record with that id

	-- NOTE: if the id has not been given, the data comes from the user interface; otherwise, it comes from the initial data;
	IF new_id IS NULL OR NOT EXISTS (SELECT * FROM texts WHERE id = new_id) THEN

		INSERT INTO texts(
			id,
			tags, 
			contents, 
			author_id,
			description, 
			properties
			)
		VALUES (
			COALESCE(new_id, nextval(pg_get_serial_sequence('texts', 'id'))),
			COALESCE(input_row.tags, '[]'::jsonb),
			input_row.contents, 
			input_row.author_id,
			COALESCE(input_row.description, '{}'::jsonb),
			COALESCE(input_row.properties, '{}'::jsonb)
			)
		RETURNING 
			*
		INTO STRICT 
			new_row;

		RETURN NEXT new_row;

	ELSE

		current_row.id = new_id;
		current_row.contents = '"WARNING: a row with the given id exists already present. Data will not be inserted."';

		RAISE WARNING 'A row with the given id exists already present. Data will not be inserted (id=%)', current_row.id;

		RETURN NEXT current_row;

	END IF;

END LOOP;

RETURN;
END;
$BODY$
LANGUAGE plpgsql;

/*
select * from texts order by id desc

select * from texts_create('[
{
	"tags": ["tag3", "tag4"],
	"contents": {"pt": "fwefwef", "en": "fwefwef fewfw"},
	"author_id": 2
}
]')

*/



/*

	3. UPDATE

*/


DROP FUNCTION IF EXISTS texts_update(json, json);

CREATE FUNCTION texts_update(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF texts AS
$$
DECLARE
	updated_row texts%ROWTYPE;
	input_row texts%ROWTYPE;
	command text;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::texts, input_data)) LOOP

	-- generate a dynamic command: first the base query
	command := 'UPDATE texts SET ';

	-- first use the fields that will always be updated
	command = format(command || 'last_updated = %L, ', now());

	-- then add (cumulatively) the fields to be updated; those fields must be present in the input_data json;
	IF input_row.tags IS NOT NULL THEN
		command = format(command || 'tags = %L, ', input_row.tags);
	END IF;
	IF input_row.contents IS NOT NULL THEN
		command = format(command || 'contents = %L, ', input_row.contents);
	END IF;
	IF input_row.description IS NOT NULL THEN
		command = format(command || 'description = %L, ', input_row.description);
	END IF;
	IF input_row.properties IS NOT NULL THEN
		command = format(command || 'properties = %L, ', input_row.properties);
	END IF;
	IF input_row.author_id IS NOT NULL THEN
		command = format(command || 'author_id = %L, ', input_row.author_id);
	END IF;
/*
	IF input_row.active IS NOT NULL THEN
		command = format(command || 'active = %L, ', input_row.active);
	END IF;
*/

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
select * from texts order by id desc

select * from texts_update('[{"id": 1, "tags": ["tag5"]}]');
select * from texts_update('[{"id": 1, "tags": ["tag7"], "contents": {"pt": "xxx"}}]');

*/






/*

	4. DELETE

*/


DROP FUNCTION IF EXISTS texts_delete(json);

CREATE FUNCTION texts_delete(options json DEFAULT '[{}]')
RETURNS TABLE(deleted_id int) AS
$$
DECLARE
	deleted_row texts%ROWTYPE;
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
		DELETE FROM texts
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

select * from texts order by id desc;

select * from texts_delete('[{"id": 253}, {"id": 253}]');
select * from texts_delete('[{"id": 13}]');
*/




