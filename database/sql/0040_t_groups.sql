/*
NOTE: the name of group is TEXT and not JSONB because it doesn't make sense for a name
to have 2 forms (in portuguese and english); the "name" in this context is more like
an identifier (like the name of a person)
*/
CREATE TABLE IF NOT EXISTS groups(
	id serial primary key,
	code int not null unique,
	name text not null unique,
	description JSONB default '{}',
	permissions JSONB default '{}',

	CONSTRAINT description_must_be_object CHECK (jsonb_typeof(description) = 'object'),
	CONSTRAINT permissions_must_be_object CHECK (jsonb_typeof(permissions) = 'object')
);


DO $$
DECLARE
	_has_executed BOOLEAN;
	_table_exists BOOLEAN;
	_flag TEXT := 'create_table_groups';
	_table_name TEXT := 'groups';
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
		PERFORM setval(pg_get_serial_sequence('groups', 'id'), 1000);
		PERFORM audit.audit_table('groups');

		-- add the flag to the table
		INSERT INTO code_has_executed(code) VALUES(_flag);
	end if;
END
$$

