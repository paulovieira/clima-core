
CREATE TABLE IF NOT EXISTS shapes( 
	id SERIAL PRIMARY KEY,
	code TEXT NOT NULL UNIQUE,  -- the name of the table will be the code
	srid INT REFERENCES spatial_ref_sys(srid) default 4326,
	description JSONB default '{}',
	file_id INT references files(id)  on update cascade on delete set null,
	schema_name TEXT NOT NULL default 'geo',
	owner_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
	created_at timestamptz not null default now(),

	CONSTRAINT description_must_be_object CHECK (jsonb_typeof(description) = 'object')
);



DO $$
DECLARE
	_has_executed BOOLEAN;
	_table_exists BOOLEAN;
	_flag TEXT := 'create_table_shapes';
	_table_name TEXT := 'shapes';
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
		PERFORM setval(pg_get_serial_sequence('shapes', 'id'), 1000);
		PERFORM audit.audit_table('shapes');

		-- add the flag to the table
		INSERT INTO code_has_executed(code) VALUES(_flag);
	end if;
END
$$

