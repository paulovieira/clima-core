
/*
NOTE: 

the id field is serial, but the sequence starts at 1000; this will reserve 1000 rows for the initial data; the logic in the texts_create function is as follows
a) if the id has not been given, it will insert the data as usual (getting the id from the sequence)
b) if the id has been given, it will check if there already is a row with that id; 
	b i) if does not exists, it will insert the data as usual (using the given id explicitely - this will not change the sequence)
	b ii) if exists, it will not insert the data (and will not raise an error, because we don't want to abort the scripts)

*/

CREATE TABLE IF NOT EXISTS  texts( 
	id SERIAL PRIMARY KEY,
	tags JSONB DEFAULT '[]',
	contents JSONB NOT NULL,
	author_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
	description JSONB default '{}',
	properties JSONB default '{}',
	active BOOLEAN DEFAULT TRUE,	
	last_updated timestamptz not null default now(),

	CONSTRAINT tags_must_be_array         CHECK (jsonb_typeof(tags) = 'array'),
	CONSTRAINT contents_must_be_object    CHECK (jsonb_typeof(contents) = 'object'),
	CONSTRAINT description_must_be_object CHECK (jsonb_typeof(description) = 'object'),
	CONSTRAINT properties_must_be_object  CHECK (jsonb_typeof(properties) = 'object')
);



DO $$
DECLARE
	_has_executed BOOLEAN;
	_table_exists BOOLEAN;
	_flag TEXT := 'create_table_texts';
	_table_name TEXT := 'texts';
BEGIN

	-- get the flag for this file
	SELECT EXISTS (
		SELECT 1 FROM code_has_executed WHERE code = _flag
	) INTO _has_executed;

	-- check if the table exists
	SELECT EXISTS (
	   SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = _table_name
	) INTO _table_exists;

	if _table_exists is true AND _has_executed is false then

		-- the following sql lines will be executed only the first time this file is run
		PERFORM setval(pg_get_serial_sequence('texts', 'id'), 1000);
		PERFORM audit.audit_table('texts');

		-- add the flag to the table
		INSERT INTO code_has_executed(code) VALUES(_flag);
	end if;
END
$$





/*
TODO: when a text is created, we could give the groups that can update the text; this means we have to create a new link table texts_groups.

An alternative (simpler) solution is to create a special group named "can_update_texts". If the user belongs to this group, he can update any text. So the permission is all-or-nothing:

	- if the user can update 1 text, he can update all of them
	- if the user cannot update 1 text, he cannot update any of the others

This way the permission to perform some action will split the set of users in a partition with 2 components:

	- the set of user who CAN change texts (any text)
	- the set of user who CANNOT change texts

That is, the permission if global (all the texts would have the same allowed users).

If we used the link table approach the permission would be more fine grained. We would have:

	- the set of users who can change this particular text (but who might not be able to change other texts)

That is, the permissi would be local (each text would have different allowed users).

*/

