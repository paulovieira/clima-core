
CREATE TABLE IF NOT EXISTS users_groups(
	id         serial,
	user_id    int references users(id)    on update cascade on delete cascade,
	group_code int references groups(code) on update cascade on delete cascade,
	primary key(user_id, group_code)
);



DO $$
DECLARE
	_has_executed BOOLEAN;
	_table_exists BOOLEAN;
	_flag TEXT := 'create_table_users_groups';
	_table_name TEXT := 'users_groups';
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
		PERFORM setval(pg_get_serial_sequence('users_groups', 'id'), 1000);
		PERFORM audit.audit_table('users_groups');

		-- add the flag to the table
		INSERT INTO code_has_executed(code) VALUES(_flag);
	end if;
END
$$




-- todo: create index?