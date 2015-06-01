
CREATE TABLE IF NOT EXISTS shapes_maps(
	id        serial,
	shape_id  int references shapes(id) on update cascade on delete cascade,
	map_id    int references maps(id)   on update cascade on delete cascade,
	primary key(shape_id, map_id)
);



DO $$
DECLARE
	_has_executed BOOLEAN;
	_table_exists BOOLEAN;
	_flag TEXT := 'create_table_shapes_maps';
	_table_name TEXT := 'shapes_maps';
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
		PERFORM setval(pg_get_serial_sequence('shapes_maps', 'id'), 1000);
		PERFORM audit.audit_table('shapes_maps');

		-- add the flag to the table
		INSERT INTO code_has_executed(code) VALUES(_flag);
	end if;
END
$$




-- todo: create index?