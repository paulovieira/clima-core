

/*

	1. READ

A group
	- has many users
	- has maby texts (but we don't need that data)

We return 
	- all the fields in the groups table + 
	- a json array of objects relative to all the users of the group

*/


DROP FUNCTION IF EXISTS groups_read(json);

CREATE FUNCTION groups_read(options json DEFAULT '[{}]')

-- return table uses the definition of the groups table + extra data from the join
RETURNS TABLE(
	id INT,
	code INT,
	name TEXT,
	description JSONB,
	permissions JSONB,
	group_users JSON   -- join with the group_users CTE
)
AS
$BODY$

DECLARE
	options_row json;
	command text;
	number_conditions INT;
	groups_users_cte TEXT;

	-- fields to be used in WHERE clause
	id INT;
	code TEXT;
BEGIN

-- NOTE: using a CTE is not good for performance;
-- NOTE: we have to make the CASE...END. See the comment in fn_users.sql
groups_users_cte := '
	groups_users_cte AS (
		SELECT
			g.id as group_id,
			g.code as group_code,
			(CASE WHEN COUNT(u) = 0 THEN ''[]''::json  ELSE json_agg(u.*) END ) AS group_users
		FROM groups g
		LEFT JOIN users_groups ug
			ON ug.group_code = g.code
		LEFT JOIN users u
			ON u.id = ug.user_id
		GROUP BY g.id
	) 
';


-- convert the json argument from object to array of (one) objects
IF  json_typeof(options) = 'object'::text THEN
	options = ('[' || options::text ||  ']')::json;
END IF;


FOR options_row IN ( select json_array_elements(options) ) LOOP

	command := 'WITH '
		|| groups_users_cte 
		|| 'SELECT 
			g.*, 
			gu.group_users
		FROM groups g
		INNER JOIN groups_users_cte gu
			ON g.id = gu.group_id';

			
	-- extract values to be (optionally) used in the WHERE clause
	SELECT json_extract_path_text(options_row, 'id')    INTO id;
	SELECT json_extract_path_text(options_row, 'code')  INTO code;

	number_conditions := 0;
	
	-- criteria: id
	IF id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' g.id = %L', id);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: code
	IF code IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' g.code = %L', code);
		number_conditions := number_conditions + 1;
	END IF;

	
	command := command || ' ORDER BY g.id;';

	RETURN QUERY EXECUTE command;

END LOOP;
		
RETURN;
END;
$BODY$
LANGUAGE plpgsql;


/*

EXAMPLES:

select * from groups

select * from  groups_read('[{"id":"1"}]');
select * from  groups_read('[{"id":"1"}]');
*/




/*

	2. CREATE

*/


DROP FUNCTION IF EXISTS groups_create(json, json);

CREATE FUNCTION groups_create(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF groups AS
$BODY$
DECLARE
	new_row groups%ROWTYPE;
	input_row groups%ROWTYPE;
	current_row groups%ROWTYPE;
	new_id INT;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::groups, input_data)) LOOP

	SELECT input_row.id INTO new_id;
	
	IF new_id IS NULL OR NOT EXISTS (SELECT * FROM groups WHERE id = new_id) THEN

		INSERT INTO groups(
			id,
			code, 
			name,
			description,
			permissions
			)
		VALUES (
			COALESCE(new_id, nextval(pg_get_serial_sequence('groups', 'id'))),
			input_row.code, 
			input_row.name,
			COALESCE(input_row.description, '{}'::jsonb),
			COALESCE(input_row.permissions, '{}'::jsonb)
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

EXAMPLES:

select * from groups order by id desc


select * from groups_create('[
{"name": "admin", "code": 99,  "description": {"pt": "desc pt", "en": "desc en"}},
{"name": "energia", "code": 1,  "description": {"pt": "desc pt", "en": "desc en"}},
{"name": "biodiversidade", "code": 2,  "description": {"pt": "desc pt", "en": "desc en"}, "permissions": { "canEditTexts": true } }
]');


select * from groups_create('[
{"name": "xadmin", "code": 99,  "description": {"pt": "desc pt", "en": "desc en"}}
]');

*/




/*

	3. UPDATE

*/


DROP FUNCTION IF EXISTS groups_update(json, json);

CREATE FUNCTION groups_update(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF groups AS
$$
DECLARE
	updated_row groups%ROWTYPE;
	input_row groups%ROWTYPE;
	command text;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::groups, input_data)) LOOP

	-- generate a dynamic command: first the base query
	command := 'UPDATE groups SET ';

	-- then add (cumulatively) the fields to be updated; those fields must be present in the input_data json;
	IF input_row.code IS NOT NULL THEN
		command = format(command || 'code = %L, ', input_row.code);
	END IF;
	IF input_row.name IS NOT NULL THEN
		command = format(command || 'name = %L, ', input_row.name);
	END IF;
	IF input_row.description IS NOT NULL THEN
		command = format(command || 'description = %L, ', input_row.description);
	END IF;
	IF input_row.permissions IS NOT NULL THEN
		command = format(command || 'permissions = %L, ', input_row.permissions);
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

EXAMPLES:

select * from groups order by id desc


select * from groups_update('[
{"id": "1", "name": "energiax"},
{"id": "4", "description": {"pt": "desc pt", "en": "desc en"}, "permissions": { "canEditTexts": true } }
]');


*/




/*

	4. DELETE

*/


DROP FUNCTION IF EXISTS groups_delete(json);

CREATE FUNCTION groups_delete(options json DEFAULT '[{}]')
RETURNS TABLE(deleted_id int) AS
$$
DECLARE
	deleted_row groups%ROWTYPE;
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
		DELETE FROM groups
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

EXAMPLES:

select * from groups order by id desc;
insert into groups(first,email,pw_hash) values ('qwe', 'qwe', 'qwe'), ('qwe2', 'qwe2', 'qwe2')

select * from groups_delete('[{"id": 253}, {"id": 253}]');
select * from groups_delete('[{"id": 13}]');
*/




