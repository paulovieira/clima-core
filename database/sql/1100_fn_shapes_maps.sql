
/*

	1. READ

*/


DROP FUNCTION IF EXISTS shapes_maps_read(json);

CREATE FUNCTION shapes_maps_read(options json DEFAULT '[{}]')

-- return table using the definition of the shapes_maps table
RETURNS TABLE(
	id       INT,
	shape_id INT,
	map_id   INT
)
AS
$BODY$

DECLARE
	options_row json;
	command text;
	number_conditions INT;

	-- fields to be used in WHERE clause
	shape_id INT;
	map_id TEXT;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(options) = 'object'::text THEN
	options = ('[' || options::text ||  ']')::json;
END IF;


FOR options_row IN ( select json_array_elements(options) ) LOOP

	command := 'SELECT * FROM shapes_maps ';
			
	-- extract values to be (optionally) used in the WHERE clause
	SELECT json_extract_path_text(options_row, 'shape_id')     INTO shape_id;
	SELECT json_extract_path_text(options_row, 'map_id')  INTO map_id;

	number_conditions := 0;
	
	-- criteria: shape_id
	IF shape_id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' shape_id = %L', shape_id);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: map_id
	IF map_id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' map_id = %L', map_id);
		number_conditions := number_conditions + 1;
	END IF;

	
	command := command || ' ORDER BY id;';

	RETURN QUERY EXECUTE command;

END LOOP;
		
RETURN;
END;
$BODY$
LANGUAGE plpgsql;




/*
select * from shapes_maps

select * from  shapes_maps_read('[{}]');
select * from  shapes_maps_read('[{"map_id": 99, "shape_id": 1}]');
select * from  shapes_maps_read('[{"shape_id":"1"}, {"shape_id":"2"}]');

*/




/*

	2. CREATE

*/


DROP FUNCTION IF EXISTS shapes_maps_create(json, json);

CREATE FUNCTION shapes_maps_create(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF shapes_maps AS
$BODY$
DECLARE
	new_row shapes_maps%ROWTYPE;
	input_row shapes_maps%ROWTYPE;
	current_row shapes_maps%ROWTYPE;
	new_id INT;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::shapes_maps, input_data)) LOOP

	SELECT input_row.id INTO new_id;
	
	IF new_id IS NULL OR NOT EXISTS (SELECT * FROM shapes_maps WHERE id = new_id) THEN

		INSERT INTO shapes_maps(
			id,
			shape_id,
			map_id
			)
		VALUES (
			COALESCE(new_id, nextval(pg_get_serial_sequence('shapes_maps', 'id'))),
			input_row.shape_id,
			input_row.map_id
			)
		RETURNING 
			*
		INTO STRICT 
			new_row;
		
		RETURN NEXT new_row;

	ELSE

		current_row.id = new_id;
--		current_row.name = '"WARNING: a row with the given id exists already present. Data will not be inserted."';

		RAISE WARNING 'A row with the given id exists already present. Data will not be inserted (id=%)', current_row.id;

		RETURN NEXT current_row;

	END IF;

END LOOP;

RETURN;
END;
$BODY$
LANGUAGE plpgsql;

/*
select * from shapes_maps order by id desc

select * from shapes_maps_create('{
	"shape_id": 1005,
	"map_id": 5
}')


*/




/*

	3. UPDATE

*/


DROP FUNCTION IF EXISTS shapes_maps_update(json, json);

CREATE FUNCTION shapes_maps_update(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF shapes_maps AS
$$
DECLARE
	updated_row shapes_maps%ROWTYPE;
	input_row shapes_maps%ROWTYPE;
	command text;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::shapes_maps, input_data)) LOOP

	-- generate a dynamic command: first the base query
	command := 'UPDATE shapes_maps SET ';

	-- then add (cumulatively) the fields to be updated; those fields must be present in the input_data json;
	IF input_row.map_id IS NOT NULL THEN
		command = format(command || 'map_id = %L, ', input_row.map_id);
	END IF;
	IF input_row.shape_id IS NOT NULL THEN
		command = format(command || 'shape_id = %L, ', input_row.shape_id);
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
select * from shapes_maps order by id desc


select * from shapes_maps_update('{
	"id": "4", 
	"shape_id": 1006
}');


*/





/*

	4. DELETE

*/

DROP FUNCTION IF EXISTS shapes_maps_delete(json);

CREATE FUNCTION shapes_maps_delete(options json DEFAULT '[{}]')
RETURNS TABLE(deleted_id int) AS
$$
DECLARE
	deleted_row shapes_maps%ROWTYPE;
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
		DELETE FROM shapes_maps
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

select * from shapes_maps order by id desc;

select * from shapes_maps_delete('{"id": 3}');

*/



