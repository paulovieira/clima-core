
/*

	1. READ

*/


DROP FUNCTION IF EXISTS maps_read(json);

CREATE FUNCTION maps_read(options json DEFAULT '[{}]')

-- return table, uses the definition of the maps table + extra data from the join
RETURNS TABLE(
	id INT,
	code TEXT,
	title JSONB,
	description JSONB,
	properties JSONB,
	category_id INT,
	controls JSONB,
	owner_id INT,
	created_at timestamptz,
--	map_shape_info JSON,
	owner_data JSON,
	category_data JSON,
	shapes_data JSON)
AS
$BODY$

DECLARE
	options_row json;
	command text;
	number_conditions INT;
	shapes_data_cte TEXT;

	-- fields to be used in WHERE clause
	id INT;
BEGIN

shapes_data_cte := '
	shapes_data_cte AS (
		SELECT
			m.id as map_id,
			(CASE WHEN COUNT(s) = 0 THEN ''[]''::json  ELSE json_agg(s.*) END ) AS shapes_data
		FROM maps m
		LEFT JOIN shapes_maps sm
			ON m.id = sm.map_id
		LEFT JOIN shapes s
			ON s.id = sm.shape_id
		GROUP BY m.id
	)
';


-- convert the json argument from object to array of (one) objects
IF  json_typeof(options) = 'object'::text THEN
	options = ('[' || options::text ||  ']')::json;
END IF;


FOR options_row IN ( select json_array_elements(options) ) LOOP


	command := 'WITH '
		|| shapes_data_cte
		||	'SELECT 
			m.*,
			(select row_to_json(_dummy_) from (select u.*) as _dummy_) as owner_data,
			(select row_to_json(_dummy_) from (select t.*) as _dummy_) as category_data,
			sd.shapes_data
		FROM maps m 
		INNER JOIN shapes_data_cte sd
			ON m.id = sd.map_id
		LEFT JOIN users u
			ON m.owner_id = u.id
		INNER JOIN texts t
			ON m.category_id = t.id';


			
	-- extract values to be (optionally) used in the WHERE clause
	SELECT json_extract_path_text(options_row, 'id')         INTO id;
	--SELECT json_extract_path_text(options_row, 'table_name_like')  INTO table_name_like;

	number_conditions := 0;

	-- criteria: id
	IF id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' m.id = %L', id);
		number_conditions := number_conditions + 1;
	END IF;

	command := command || ' ORDER BY m.id;';

	RETURN QUERY EXECUTE command;

END LOOP;
		
RETURN;
END;
$BODY$
LANGUAGE plpgsql;



/*
select * from maps

select * from maps_read('{}');


*/




/*

	2. CREATE

*/


DROP FUNCTION IF EXISTS maps_create(json, json);

CREATE FUNCTION maps_create(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF maps AS
$BODY$
DECLARE
	new_row maps%ROWTYPE;
	input_row maps%ROWTYPE;
	current_row maps%ROWTYPE;
	new_id INT;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::maps, input_data)) LOOP

	SELECT input_row.id INTO new_id;

	-- we proceed with the insert in 2 cases: 
	--   a) if the id was not given (in which case we retrieve a new id from the sequence); 
	--   b) if the id was given and there is no record with that id

	-- NOTE: if the id has not been given, the data comes from the user interface; otherwise, it comes from the initial data;
	IF new_id IS NULL OR NOT EXISTS (SELECT * FROM maps WHERE id = new_id) THEN

		INSERT INTO maps(
			id,
			code,
			title, 
			description, 
			properties,
			category_id,
			controls, 
			owner_id
			)
		VALUES (
			COALESCE(new_id, nextval(pg_get_serial_sequence('maps', 'id'))),
			input_row.code, 
			COALESCE(input_row.title, '[]'::jsonb),
			COALESCE(input_row.description, '{}'::jsonb),
			COALESCE(input_row.properties, '{}'::jsonb),
			input_row.category_id,
			COALESCE(input_row.controls, '[]'::jsonb), 
			input_row.owner_id
			)
		RETURNING 
			*
		INTO STRICT 
			new_row;

		RETURN NEXT new_row;

	ELSE
		current_row.id = new_id;
		current_row.code = '"WARNING: a row with the given id exists already present. Data will not be inserted."';

		RAISE WARNING 'A row with the given id exists already present. Data will not be inserted (id=%)', current_row.id;

		RETURN NEXT current_row;

	END IF;

END LOOP;

RETURN;
END;
$BODY$
LANGUAGE plpgsql;

/*
select * from maps order by id desc

select * from maps_create('{
	"code": "code a",
	"title": {"pt": "fwefwef", "en": "fwefwef fewfw"},
	"description": {"pt": "xxx", "en": "yyy"},
	"category_id": 105,
	"controls": [{"a": 111}],
	"owner_id": 2
}')

*/


/*

	3. UPDATE

*/


DROP FUNCTION IF EXISTS maps_update(json, json);

CREATE FUNCTION maps_update(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF maps AS
$$
DECLARE
	updated_row maps%ROWTYPE;
	input_row maps%ROWTYPE;
	command text;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::maps, input_data)) LOOP

	-- generate a dynamic command: first the base query
	command := 'UPDATE maps SET ';

	-- then add (cumulatively) the fields to be updated; those fields must be present in the input_data json;
	IF input_row.code IS NOT NULL THEN
		command = format(command || 'code = %L, ', input_row.code);
	END IF;
	IF input_row.title IS NOT NULL THEN
		command = format(command || 'title = %L, ', input_row.title);
	END IF;
	IF input_row.description IS NOT NULL THEN
		command = format(command || 'description = %L, ', input_row.description);
	END IF;
	IF input_row.properties IS NOT NULL THEN
		command = format(command || 'properties = %L, ', input_row.properties);
	END IF;
	IF input_row.category_id IS NOT NULL THEN
		command = format(command || 'category_id = %L, ', input_row.category_id);
	END IF;
	IF input_row.controls IS NOT NULL THEN
		command = format(command || 'controls = %L, ', input_row.controls);
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
select * from maps order by id desc

select * from maps_update('{
	"id": 1,
	"code": "code b",
	"title": {"pt": "zzzfwefwef", "en": "zzzfwefwef fewfw"},
	"description": {"pt": "qqqxxx", "en": "wwwyyy"},
	"controls": [{"b": 2111}],
	"owner_id": 1
}');


*/



/*

	4. DELETE

*/


DROP FUNCTION IF EXISTS maps_delete(json);

CREATE FUNCTION maps_delete(options json DEFAULT '[{}]')
RETURNS TABLE(deleted_id int) AS
$$
DECLARE
	deleted_row maps%ROWTYPE;
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
		DELETE FROM maps
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

select * from maps order by id desc;

select * from maps_delete('{"id": 1}');
*/
