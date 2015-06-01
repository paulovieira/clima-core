--select * from users order by id desc;
--delete from users where id >= 3


/*

	1. READ
 
A user
	- has many texts (because texts has a reference to user.id, so we get a 1-to-many from users to texts)
	- has many groups (because we have a many-to-many relating users and groups, thanks to the link table)

We return 
	- all the fields in the user table + 
	- a json array of objects relative to all the texts of the user + 
	- a json array of objects relative to all the groups of the user

We use two CTEs to pre-compute these json array. The CTEs have 2 fields: 

	-the user id
	-a json array of objects relative to all the texts that are related to the user (possibly empty)

	-the user id
	-a json array of objects relative to all the groups that are related to the user (possibly empty)

*/


DROP FUNCTION IF EXISTS users_read(json);

CREATE FUNCTION users_read(options json DEFAULT '[{}]')

-- return table uses the definition of the users table + extra data from the join
RETURNS TABLE(
	id INT,
	email TEXT,
	first_name TEXT,
	last_name TEXT,
	pw_hash TEXT,
	created_at timestamptz,
	recover TEXT,
	recover_valid_until timestamptz,
	user_texts JSON,  -- join with the users_texts CTE
	user_groups JSON   -- join with the users_groups CTE
)
AS
$BODY$

DECLARE
	options_row json;
	command text;
	number_conditions INT;
	users_texts_cte TEXT;
	users_groups_cte TEXT;

	-- fields to be used in WHERE clause
	id INT;
	email TEXT;
	email_like TEXT;
	recover TEXT;
BEGIN

-- convert the json argument from object to array of (one) objects
IF  json_typeof(options) = 'object'::text THEN
	options = ('[' || options::text ||  ']')::json;
END IF;


-- NOTE: using a CTE is not good for performance;

users_texts_cte := '
	users_texts_cte AS (
		SELECT
			u.id AS user_id,
			(CASE WHEN COUNT(t) = 0 THEN ''[]''::json  ELSE json_agg(t.*) END ) AS user_texts
		FROM users u
		LEFT JOIN texts t
			ON t.author_id = u.id
		GROUP BY u.id
	)
';

/*
NOTE: we have to make the CASE...END instead of simply "json_agg(g.*) AS user_groups" because if there is
no match in the LEFT JOIN, postgres returns [null] (instead of [])
*/

users_groups_cte := '
	users_groups_cte AS (
		SELECT
			u.id as user_id,
			(CASE WHEN COUNT(g) = 0 THEN ''[]''::json  ELSE json_agg(g.*) END ) AS user_groups
		FROM users u
		LEFT JOIN users_groups ug
			ON ug.user_id = u.id
		LEFT JOIN groups g
			ON g.code = ug.group_code
		GROUP BY u.id
	)
';



FOR options_row IN ( select json_array_elements(options) ) LOOP

	command := 'WITH '
		|| users_texts_cte || ', '
		|| users_groups_cte
		|| 'SELECT 
			u.*, 
			ut.user_texts,
			ug.user_groups
		FROM users u
		INNER JOIN users_texts_cte ut
			ON u.id = ut.user_id
		INNER JOIN users_groups_cte ug
			ON u.id = ug.user_id';
			
	-- extract values to be (optionally) used in the WHERE clause
	SELECT json_extract_path_text(options_row, 'id')    INTO id;
	SELECT json_extract_path_text(options_row, 'email') INTO email;
	SELECT json_extract_path_text(options_row, 'email_like') INTO email_like;
	SELECT json_extract_path_text(options_row, 'recover') INTO recover;

	number_conditions := 0;
	
	-- criteria: id
	IF id IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' u.id = %L', id);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: email
	IF email IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' u.email = %L', email);
		number_conditions := number_conditions + 1;
	END IF;

	-- criteria: email_like
	IF email_like IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		email_like := '%' || email_like || '%';
		command = format(command || ' u.email ILIKE %L', email_like);
		number_conditions := number_conditions + 1;
	END IF;
	
	-- criteria: recover token
	IF recover IS NOT NULL THEN
		IF number_conditions = 0 THEN  command = command || ' WHERE';  
		ELSE                           command = command || ' AND';
		END IF;

		command = format(command || ' u.recover = %L', recover);
		number_conditions := number_conditions + 1;
	END IF;

	command := command || ' ORDER BY u.id;';

	RETURN QUERY EXECUTE command;

END LOOP;
		
RETURN;
END;
$BODY$
LANGUAGE plpgsql;


/*

EXAMPLES:

select * from  users_read();
select * from  users_read('[{"email":"paulovieira@gmail.com"}]');
select * from  users_read('[{"id":2}, {"id":1}]');
select * from  users_read('[{"email_like": "pau"}]');

*/



/*

	2. CREATE

*/

DROP FUNCTION IF EXISTS users_create(json, json);

CREATE FUNCTION users_create(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF users AS
$BODY$
DECLARE
	new_row users%ROWTYPE;
	input_row users%ROWTYPE;
	current_row users%ROWTYPE;
	new_id INT;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::users, input_data)) LOOP

	SELECT input_row.id INTO new_id;

	IF new_id IS NULL OR NOT EXISTS (SELECT * FROM users WHERE id = new_id) THEN

		INSERT INTO users(
			id,
			email, 
			first_name, 
			last_name, 
			pw_hash
			)
		VALUES (
			COALESCE(new_id, nextval(pg_get_serial_sequence('users', 'id'))),
			input_row.email, 
			input_row.first_name, 
			input_row.last_name, 
			input_row.pw_hash
			)
		RETURNING 
			*
		INTO STRICT 
			new_row;

		RETURN NEXT new_row;

	ELSE

		current_row.id = new_id;
		current_row.email = '"WARNING: a row with the given id exists already present. Data will not be inserted."';

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

select * from users order by id desc
delete from users where id >= 244

select * from users_create('[{"first_name": "232", "email": "@232", "pw_hash": ""},{"first_name": "233", "email": "@233", "pw_hash": "dd"}]');




select * from users_create('[
{"email": "@500", "first_name": "", "pw_hash": ""},
{"email": "@501", "first_name": "", "pw_hash": ""},
{"email": "@502", "first_name": "", "pw_hash": ""},
{"email": "@503", "first_name": "", "pw_hash": ""},
{"email": "@504", "first_name": "", "pw_hash": ""}
]'
);


NOTES: some quick benchmarks
insert 5 rows: ~300ms
insert 10 rows: ~700ms
insert 20 rows: ~1400ms
insert 30 rows: ~2100ms (!)

The time is clearly growing linearly;

*/





/*

	3. UPDATE

*/


DROP FUNCTION IF EXISTS users_update(json, json);

CREATE FUNCTION users_update(input_data json, options json DEFAULT '[{}]')
RETURNS SETOF users AS
$$
DECLARE
	updated_row users%ROWTYPE;
	input_row users%ROWTYPE;
	command text;
BEGIN


-- convert the json argument from object to array of (one) objects
IF  json_typeof(input_data) = 'object'::text THEN
	input_data = ('[' || input_data::text ||  ']')::json;
END IF;


FOR input_row IN (select * from json_populate_recordset(null::users, input_data)) LOOP

	-- generate a dynamic command: first the base query
	command := 'UPDATE users SET ';

	-- then add (cumulatively) the fields to be updated; those fields must be present in the input_data json;
	IF input_row.email IS NOT NULL THEN
		command = format(command || 'email = %L, ', input_row.email);
	END IF;
	IF input_row.first_name IS NOT NULL THEN
		command = format(command || 'first_name = %L, ', input_row.first_name);
	END IF;
	IF input_row.last_name IS NOT NULL THEN
		command = format(command || 'last_name = %L, ', input_row.last_name);
	END IF;
	IF input_row.pw_hash IS NOT NULL THEN
		command = format(command || 'pw_hash = %L, ', input_row.pw_hash);
	END IF;
	IF input_row.recover IS NOT NULL THEN
		command = format(command || 'recover = %L, recover_valid_until = %L, ', input_row.recover, now() + interval '1 day');
	END IF;
/*
	IF input_row.recover_valid_until IS NOT NULL THEN
		command = format(command || 'recover_valid_until = %L, ', input_row.recover_valid_until);
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

EXAMPLES:

select * from users order by id desc

select * from users_update('[{"id": "237", "email": "@237-2"}]');
select * from users_update('[{"id": "237", "email": "@237-5", "first_name": "237-3"}]');
select * from users_update('[{"id": "2370", "email": "@237-6", "recover": "zzz"}]');

select * from users_update('[{"id": "8", "recover": "zzz"}]');

select * from users_update('[
{"id": "400", "email": "@400-#8", "recover": "#8"},
{"id": "401", "email": "@401-#8", "recover": "#8"},
{"id": "402", "email": "@402-#8", "recover": "#8"},
{"id": "403", "email": "@403-#8", "recover": "#8"},
{"id": "404", "email": "@404-#8", "recover": "#8"},
]');


NOTES: results from a quick benchmark:
Update 5 rows: 30ms
Update 10 rows: 40ms
Update 20 rows: 40ms
Update 30 rows: 40ms

(the number of rows doesn't seem to matter much)

*/






/*

	4. DELETE

*/


DROP FUNCTION IF EXISTS users_delete(json);

CREATE FUNCTION users_delete(options json DEFAULT '[{}]')
RETURNS TABLE(deleted_id int) AS
$$
DECLARE
	deleted_row users%ROWTYPE;
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
		DELETE FROM users u
		WHERE u.id = id_to_delete
		RETURNING *
		INTO deleted_row;

		deleted_id := deleted_row.id;

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

select * from users order by id desc;
insert into users(first,email,pw_hash) values ('qwe', 'qwe', 'qwe'), ('qwe2', 'qwe2', 'qwe2')

select * from users_delete('[{"id": 253}, {"id": 253}]');
select * from users_delete('[{"id": 13}]');

*/




