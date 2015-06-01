--select * from users_groups order by id desc;
--delete from users_groups where id >= 3


/*

	1. READ

*/


DROP FUNCTION IF EXISTS users_groups_read(json);

CREATE FUNCTION users_groups_read(options json DEFAULT '[{}]')

-- return table using the definition of the users_groups table
RETURNS TABLE(
	id         INT,
	user_id    INT,
	group_code INT
)
AS
$BODY$

DECLARE
	options_row json;
	command text;
	number_conditions INT;

	-- fields to be used in WHERE clause
	user_id INT;
	group_code TEXT;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(options) = 'object'::text THEN
	options = ('[' || options::text ||  ']')::json;
END IF;


FOR options_row IN ( select json_array_elements(options) ) LOOP

	command := 'SELECT * FROM users_groups ';
			
	-- extract values to be (optionally) used in the WHERE clause
	SELECT json_extract_path_text(options_row, 'user_id')     INTO user_id;
	SELECT json_extract_path_text(options_row, 'group_code')  INTO group_code;

	number_conditions := 0;
	
	-- criteria: user_id
	IF user_id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' user_id = %L', user_id);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: group_code
	IF group_code IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' group_code = %L', group_code);
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
select * from users_groups

select * from  users_groups_read('[{}]');
select * from  users_groups_read('[{"group_code": 99, "user_id": 1}]');
select * from  users_groups_read('[{"user_id":"1"}, {"user_id":"2"}]');

*/




/*

	2. CREATE

*/


DROP FUNCTION IF EXISTS users_groups_create(json, json);

CREATE FUNCTION users_groups_create(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF users_groups AS
$BODY$
DECLARE
	new_row users_groups%ROWTYPE;
	input_row users_groups%ROWTYPE;
	current_row users_groups%ROWTYPE;
	new_id INT;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::users_groups, input_data)) LOOP

	SELECT input_row.id INTO new_id;
	
	IF new_id IS NULL OR NOT EXISTS (SELECT * FROM users_groups WHERE id = new_id) THEN

		INSERT INTO users_groups(
			id,
			group_code, 
			user_id
			)
		VALUES (
			COALESCE(new_id, nextval(pg_get_serial_sequence('users_groups', 'id'))),
			input_row.group_code, 
			input_row.user_id
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
select * from users_groups order by id desc

select * from users_groups_create('[{"user_id": 40, "group_code": 25}]');

select * from users_groups_create('[
	{"user_id": 41, "group_code": 1}, 
	{"user_id": 41, "group_code": 2}
]');


*/




/*

	3. UPDATE

*/


DROP FUNCTION IF EXISTS users_groups_update(json, json);

CREATE FUNCTION users_groups_update(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF users_groups AS
$$
DECLARE
	updated_row users_groups%ROWTYPE;
	input_row users_groups%ROWTYPE;
	command text;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::users_groups, input_data)) LOOP

	-- generate a dynamic command: first the base query
	command := 'UPDATE users_groups SET ';

	-- then add (cumulatively) the fields to be updated; those fields must be present in the input_data json;
	IF input_row.group_code IS NOT NULL THEN
		command = format(command || 'group_code = %L, ', input_row.group_code);
	END IF;
	IF input_row.user_id IS NOT NULL THEN
		command = format(command || 'user_id = %L, ', input_row.user_id);
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
select * from users_groups order by id desc


select * from users_groups_update('[
	{"id": "2", "user_id": 41},
	{"id": "3", "user_id": 40}
]');


*/





/*

	4. DELETE

*/

DROP FUNCTION IF EXISTS users_groups_delete(json);

CREATE FUNCTION users_groups_delete(options json DEFAULT '[{}]')
RETURNS TABLE(deleted_id int) AS
$$
DECLARE
	deleted_row users_groups%ROWTYPE;
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
		DELETE FROM users_groups
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

select * from users_groups order by id desc;
select * from users_groups_delete('[{"id": 3}]');
*/



