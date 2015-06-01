
/*

	1. READ

*/


DROP FUNCTION IF EXISTS files_read(json);

CREATE FUNCTION files_read(options json DEFAULT '[{}]')

-- return table, uses the definition of the files table + extra data from the join
RETURNS TABLE(
	id INT,
	name TEXT,
	logical_path TEXT,
	physical_path TEXT,	
	tags JSONB,
	description JSONB,
	properties JSONB,
	owner_id INT,
	uploaded_at timestamptz,
	owner_data JSON)
AS
$BODY$

DECLARE
	options_row json;
	command text;
	number_conditions INT;

	-- fields to be used in WHERE clause
	id INT;
	owner_id INT;
	author_email TEXT;
	tags TEXT;
	name TEXT;
	logical_path TEXT;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(options) = 'object'::text THEN
	options = ('[' || options::text ||  ']')::json;
END IF;


FOR options_row IN ( select json_array_elements(options) ) LOOP

	command := 'SELECT 
			f.*, 
			(select row_to_json(_dummy_) from (select u.*) as _dummy_) as owner_data
		FROM files f 
		LEFT JOIN users u
		ON f.owner_id = u.id';
			
	-- extract values to be (optionally) used in the WHERE clause
	SELECT json_extract_path_text(options_row, 'id')           INTO id;
	SELECT json_extract_path_text(options_row, 'owner_id')     INTO owner_id;
	SELECT json_extract_path_text(options_row, 'author_email') INTO author_email;
	SELECT json_extract_path_text(options_row, 'tags')         INTO tags;
	SELECT json_extract_path_text(options_row, 'name')         INTO name;
	SELECT json_extract_path_text(options_row, 'logical_path') INTO logical_path;

	number_conditions := 0;

	-- criteria: id
	IF id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' f.id = %L', id);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: owner_id
	IF owner_id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' f.owner_id = %L', owner_id);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: tags
	IF tags IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' f.tags ?| ARRAY[%L]', tags);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: name
	IF name IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' f.name = %L', name);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: logical_path
	IF logical_path IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' f.logical_path = %L', logical_path);
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

	command := command || ' ORDER BY f.id;';

	RETURN QUERY EXECUTE command;

END LOOP;
		
RETURN;
END;
$BODY$
LANGUAGE plpgsql;



/*
select * from files

select * from files_read('[{}]');
select * from files_read('[{"tags": "tag1"}]');
select * from  files_read('[{"email":"paulovieira@gmail.com"}, {"id":"2"}]');
select * from  files_read('[{"id":"1"}]');
select * from  files_read('[{"owner_id":"2"}]');

*/




/*

	2. CREATE

*/


DROP FUNCTION IF EXISTS files_create(json, json);

CREATE FUNCTION files_create(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF files AS
$BODY$
DECLARE
	new_row     files%ROWTYPE;
	input_row   files%ROWTYPE;
	current_row files%ROWTYPE;

	new_id INT;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;



FOR input_row IN (select * from json_populate_recordset(null::files, input_data)) LOOP

	SELECT input_row.id INTO new_id;

	-- we proceed with the insert in 2 cases: 
	--   a) if the id was not given (in which case we retrieve a new id from the sequence); 
	--   b) if the id was given and there is no record with that id

	-- NOTE: if the id has not been given, the data comes from the user interface; otherwise, it comes from the initial data;
	IF new_id IS NULL OR NOT EXISTS (SELECT * FROM files WHERE id = new_id) THEN

		INSERT INTO files(
			id,
			name,
			logical_path,
			physical_path,
			tags, 
			description,
			properties, 
			owner_id
			)
		VALUES (
			COALESCE(new_id, nextval(pg_get_serial_sequence('files', 'id'))),
			input_row.name, 
			input_row.logical_path, 
			input_row.physical_path, 
			COALESCE(input_row.tags, '[]'::jsonb),
			COALESCE(input_row.description, '{}'::jsonb),
			COALESCE(input_row.properties, '{}'::jsonb),
			input_row.owner_id
			)
		RETURNING 
			*
		INTO STRICT 
			new_row;

		RETURN NEXT new_row;

	ELSE

		current_row.id = new_id;
		current_row.name = '"WARNING: a row with the given id exists already present. Data will not be inserted."';

		RAISE WARNING 'A row with the given id exists already present. Data will not be inserted (id=%)', current_row.id;

		RETURN NEXT current_row;

	END IF;

END LOOP;

RETURN;
END;
$BODY$
LANGUAGE plpgsql;

/*
select * from files order by id desc

select * from files_create('[
{
	"name": "relatório.pdf",
	"logical_path": "/upload/paulo",
	"physical_path": "/data",
	"tags": ["tag3", "tag4"],
	"owner_id": 2
}
]')


select * from files_create('[
{
	"name": "relatório3.pdf",
	"logical_path": "/upload/paulo",
	"physical_path": "/data",
	"owner_id": 2,
	"id": 1
}
]')

*/



/*

	3. UPDATE

*/


DROP FUNCTION IF EXISTS files_update(json, json);

CREATE FUNCTION files_update(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF files AS
$$
DECLARE
	updated_row files%ROWTYPE;
	input_row files%ROWTYPE;
	command text;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::files, input_data)) LOOP

	-- generate a dynamic command: first the base query
	command := 'UPDATE files SET ';

	-- first use the fields that will always be updated
--	command = format(command || 'uploaded_at = %L, ', now());

	-- then add (cumulatively) the fields to be updated; those fields must be present in the input_data json;
	IF input_row.name IS NOT NULL THEN
		command = format(command || 'name = %L, ', input_row.name);
	END IF;
	IF input_row.logical_path IS NOT NULL THEN
		command = format(command || 'logical_path = %L, ', input_row.logical_path);
	END IF;
	IF input_row.physical_path IS NOT NULL THEN
		command = format(command || 'physical_path = %L, ', input_row.physical_path);
	END IF;
	IF input_row.tags IS NOT NULL THEN
		command = format(command || 'tags = %L, ', input_row.tags);
	END IF;
	IF input_row.description IS NOT NULL THEN
		command = format(command || 'description = %L, ', input_row.description);
	END IF;
	IF input_row.properties IS NOT NULL THEN
		command = format(command || 'properties = %L, ', input_row.properties);
	END IF;
	IF input_row.owner_id IS NOT NULL THEN
		command = format(command || 'owner_id = %L, ', input_row.owner_id);
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
select * from files order by id desc

select * from files_update('[{"id": 1, "name": "relatório2.pdf", "tags": ["tag5"]}]');
select * from files_update('[{"id": 1, "tags": ["tag7"] }]');

*/






/*

	4. DELETE

*/


DROP FUNCTION IF EXISTS files_delete(json);

CREATE FUNCTION files_delete(options json DEFAULT '[{}]')
RETURNS TABLE(deleted_id int) AS
$$
DECLARE
	deleted_row files%ROWTYPE;
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
		DELETE FROM files
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

select * from files order by id desc;

select * from files_delete('[{"id": 253}, {"id": 253}]');
select * from files_delete('[{"id": 13}]');
*/




