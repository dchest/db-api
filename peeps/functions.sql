----------------------------
------ pg_catalog FUNCTIONS:
----------------------------

-- used by other functions, below, for any random strings needed
CREATE OR REPLACE FUNCTION pg_catalog.random_string(length integer) RETURNS text AS $$
DECLARE
	chars text[] := '{0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z,a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}';
	result text := '';
	i integer := 0;
BEGIN
	FOR i IN 1..length LOOP
		result := result || chars[1+random()*(array_length(chars, 1)-1)];
	END LOOP;
	RETURN result;
END;
$$ LANGUAGE plpgsql;


-- ensure unique unused value for any table.field.
CREATE OR REPLACE FUNCTION pg_catalog.unique_for_table_field(str_len integer, table_name text, field_name text) RETURNS text AS $$
DECLARE
	nu text;
	rowcount integer;
BEGIN
	nu := random_string(str_len);
	LOOP
		EXECUTE 'SELECT 1 FROM ' || table_name || ' WHERE ' || field_name || ' = ' || quote_literal(nu);
		GET DIAGNOSTICS rowcount = ROW_COUNT;
		IF rowcount = 0 THEN
			RETURN nu; 
		END IF;
		nu := random_string(str_len);
	END LOOP;
END;
$$ LANGUAGE plpgsql;


-- For updating foreign keys, array of tables referencing this one.  USAGE: see merge function below.
-- Returns in schema.table format like {'woodegg.researchers', 'musicthoughts.contributors'}
CREATE OR REPLACE FUNCTION pg_catalog.tables_referencing(my_schema text, my_table text, my_column text) RETURNS text[] AS $$
DECLARE
	tables text[] := ARRAY[]::text[];
BEGIN
	SELECT ARRAY(
		SELECT CONCAT(R.TABLE_SCHEMA, '.', R.TABLE_NAME)
			FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE U
				INNER JOIN INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS FK
					ON U.CONSTRAINT_CATALOG = FK.UNIQUE_CONSTRAINT_CATALOG
					AND U.CONSTRAINT_SCHEMA = FK.UNIQUE_CONSTRAINT_SCHEMA
					AND U.CONSTRAINT_NAME = FK.UNIQUE_CONSTRAINT_NAME
				INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE R
					ON R.CONSTRAINT_CATALOG = FK.CONSTRAINT_CATALOG
					AND R.CONSTRAINT_SCHEMA = FK.CONSTRAINT_SCHEMA
					AND R.CONSTRAINT_NAME = FK.CONSTRAINT_NAME
			WHERE U.COLUMN_NAME = my_column
				AND U.TABLE_SCHEMA = my_schema
				AND U.TABLE_NAME = my_table) INTO tables;
	RETURN tables;
END;
$$ LANGUAGE plpgsql;



----------------------------
----------- peeps FUNCTIONS:
----------------------------

-- pgcrypto for people.hashpass
CREATE FUNCTION crypt(text, text) RETURNS text AS '$libdir/pgcrypto', 'pg_crypt' LANGUAGE c IMMUTABLE STRICT;
CREATE FUNCTION gen_salt(text, integer) RETURNS text AS '$libdir/pgcrypto', 'pg_gen_salt_rounds' LANGUAGE c STRICT;


-- Use this to add a new person to the database.  Ensures unique email without clash.
-- USAGE: SELECT * FROM person_create('Dude Abides', 'dude@abid.es');
-- Will always return peeps.people row, whether new INSERT or existing SELECT
CREATE FUNCTION person_create(new_name text, new_email text) RETURNS SETOF peeps.people AS $$
DECLARE
	clean_email text;
BEGIN
	clean_email := lower(regexp_replace(new_email, '\s', '', 'g'));
	IF clean_email IS NULL OR clean_email = '' THEN
		RAISE 'missing_email';
	END IF;
	IF NOT EXISTS (SELECT 1 FROM peeps.people WHERE email = clean_email) THEN
		RETURN QUERY INSERT INTO peeps.people (name, email) VALUES (new_name, clean_email) RETURNING peeps.people.*;
	ELSE
		RETURN QUERY SELECT * FROM peeps.people WHERE email = clean_email;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- Use this for user choosing their own password.
-- USAGE: SELECT set_password(123, 'Th€IR nü FunK¥(!) pá$$werđ');
-- Returns false if that peeps.people.id doesn't exist, otherwise true.
CREATE FUNCTION set_password(person_id integer, password text) RETURNS boolean AS $$
BEGIN
	IF password IS NULL OR length(btrim(password)) < 4 THEN
		RAISE 'short_password';
	END IF;
	UPDATE peeps.people SET newpass=NULL, hashpass=crypt(password, gen_salt('bf', 8)) WHERE id = person_id;
	IF FOUND THEN
		RETURN true;
	ELSE
		RETURN false;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- Use this when a user is logging in with their email and (their own chosen) password.
-- USAGE: SELECT * FROM person_email_pass('dude@abid.es', 'Th€IR öld FunK¥ pá$$werđ');
-- Returns peeps.people.* if both are correct, or nothing if not.
-- Once authorized here, give logins or api_key cookie for future lookups.
CREATE FUNCTION person_email_pass(my_email text, my_pass text) RETURNS SETOF peeps.people AS $$
DECLARE
	clean_email text;
BEGIN
	clean_email := lower(regexp_replace(my_email, '\s', '', 'g'));
	IF clean_email !~ '\A\S+@\S+\.\S+\Z' THEN
		RAISE 'bad_email';
	END IF;
	IF my_pass IS NULL OR length(btrim(my_pass)) < 4 THEN
		RAISE 'short_password';
	END IF;
	RETURN QUERY SELECT * FROM peeps.people WHERE email=clean_email AND hashpass=crypt(my_pass, hashpass);
END;
$$ LANGUAGE plpgsql;


-- Use this to find users matching query string, whether in their name, email address, or company.
-- USAGE: SELECT * FROM people_search('wonka');
-- Returns peeps.people.* rows found
CREATE FUNCTION people_search(term text) RETURNS SETOF peeps.people AS $$
DECLARE
	q text := '%' || btrim(term) || '%';
BEGIN
	IF length(btrim(term)) < 2 THEN
		RAISE 'short_search_term';
	END IF;
	RETURN QUERY SELECT * FROM peeps.people WHERE name ILIKE q OR company ILIKE q OR email ILIKE q;
END;
$$ LANGUAGE plpgsql;


-- When a person has multiple entries in peeps.people, merge two into one, updating foreign keys.
-- USAGE: SELECT person_merge_from_to(5432, 4321);
-- Returns array of tables actually updated in schema.table format like {'muckwork.clients', 'sivers.comments'}
-- (Return value is probably unneeded, but here it is anyway, just in case.)
CREATE FUNCTION person_merge_from_to(old_id integer, new_id integer) RETURNS text[] AS $$
DECLARE
	done_tables text[] := ARRAY[]::text[];
	a_table text;
	rowcount integer;
BEGIN
	FOREACH a_table IN ARRAY tables_referencing('peeps', 'people', 'id') LOOP
		EXECUTE 'UPDATE ' || a_table || ' SET person_id=' || new_id || ' WHERE person_id=' || old_id || ' RETURNING person_id';
		GET DIAGNOSTICS rowcount = ROW_COUNT;
		IF rowcount > 0 THEN
			done_tables := done_tables || a_table;
		END IF;
	END LOOP;
	DELETE FROM peeps.people WHERE id = old_id;
	RETURN done_tables;
END;
$$ LANGUAGE plpgsql;


-- Returns emails.* only if emailers.profiles && emailers.cateories matches
CREATE FUNCTION emailer_get_email(emailer_id integer, email_id integer) RETURNS SETOF peeps.emails AS $$
DECLARE
	emailer emailers;
	email emails;
BEGIN
	SELECT * INTO emailer FROM peeps.emailers WHERE id = emailer_id;
	SELECT * INTO email FROM peeps.emails WHERE id = email_id;
	IF (emailer.profiles = '{ALL}' AND emailer.categories = '{ALL}') OR
	   (emailer.profiles = '{ALL}' AND email.category = ANY(emailer.categories)) OR
	   (email.profile = ANY(emailer.profiles) AND emailer.categories = '{ALL}') OR
	   (email.profile = ANY(emailer.profiles) AND email.category = ANY(emailer.categories)) THEN
		RETURN QUERY SELECT * FROM peeps.emails WHERE id = email_id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- Returns unopened emails.* that this emailer is authorized to see
CREATE FUNCTION emailer_get_unopened(emailer_id integer) RETURNS SETOF peeps.emails AS $$
DECLARE
	qry text := 'SELECT * FROM peeps.emails WHERE opened_at IS NULL AND person_id IS NOT NULL';
	emailer emailers;
BEGIN
	SELECT * INTO emailer FROM peeps.emailers WHERE id = emailer_id;
	IF (emailer.profiles != '{ALL}') THEN
		qry := qry || ' AND profile IN (SELECT UNNEST(profiles) FROM peeps.emailers WHERE id=' || emailer_id || ')';
	END IF;
	IF (emailer.categories != '{ALL}') THEN
		qry := qry || ' AND category IN (SELECT UNNEST(categories) FROM peeps.emailers WHERE id=' || emailer_id || ')';
	END IF;
	qry := qry || ' ORDER BY id ASC';
	RETURN QUERY EXECUTE qry;
END;
$$ LANGUAGE plpgsql;


-- Once a person has correctly given their email and password, call this to create cookie info.
-- Returns a single 65-character string, ready to be set as the cookie value
CREATE FUNCTION login_person_domain(my_person_id integer, my_domain char) RETURNS text AS $$
DECLARE
	c_id text;
	c_tok text;
	c_exp integer;
BEGIN
	c_id := md5(my_domain || md5(my_person_id::char)); -- also in get_person_from_cookie
	c_tok := random_string(32);
	c_exp := FLOOR(EXTRACT(epoch from (NOW() + interval '1 year')));
	INSERT INTO peeps.logins(person_id, cookie_id, cookie_tok, cookie_exp, domain) VALUES (my_person_id, c_id, c_tok, c_exp, my_domain);
	RETURN CONCAT(c_id, ':', c_tok);
END;
$$ LANGUAGE plpgsql;


-- Give the cookie value returned from login_person_domain, and I'll return people.* if found and not expired
CREATE FUNCTION get_person_from_cookie(cookie char) RETURNS SETOF peeps.people AS $$
DECLARE
	c_id text;
	c_tok text;
	a_login logins;
BEGIN
	c_id := split_part(cookie, ':', 1);
	c_tok := split_part(cookie, ':', 2);
	SELECT * INTO a_login FROM peeps.logins WHERE cookie_id=c_id AND cookie_tok=c_tok;
	IF FOUND AND
	  a_login.cookie_exp > FLOOR(EXTRACT(epoch from NOW())) AND
	  c_id = md5(a_login.domain || md5(a_login.person_id::char)) THEN
		RETURN QUERY SELECT * FROM peeps.people WHERE id=a_login.person_id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- ids of unopened emails this emailer is allowed to access
-- PARAMS: emailer_id
CREATE FUNCTION unopened_email_ids(integer) RETURNS SETOF integer AS $$
DECLARE
	pros text[];
	cats text[];
BEGIN
	SELECT profiles, categories INTO pros, cats FROM emailers WHERE id = $1;
	IF pros = array['ALL'] AND cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL ORDER BY id;
	ELSIF cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL AND profile = ANY(pros) ORDER BY id;
	ELSIF pros = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL AND category = ANY(cats) ORDER BY id;
	ELSE
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL
			AND profile = ANY(pros) AND category = ANY(cats) ORDER BY id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- ids of already-open emails this emailer is allowed to access
-- PARAMS: emailer_id
CREATE FUNCTION opened_email_ids(integer) RETURNS SETOF integer AS $$
DECLARE
	pros text[];
	cats text[];
BEGIN
	SELECT profiles, categories INTO pros, cats FROM emailers WHERE id = $1;
	IF pros = array['ALL'] AND cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL ORDER BY id;
	ELSIF cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL AND profile = ANY(pros) ORDER BY id;
	ELSIF pros = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL AND category = ANY(cats) ORDER BY id;
	ELSE
		RETURN QUERY SELECT id FROM emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL
			AND profile = ANY(pros) AND category = ANY(cats) ORDER BY id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- ids of unknown-person emails, if this emailer is admin or allowed
-- (unknown-person emails don't have categories, so not checking for that)
-- PARAMS: emailer_id
CREATE FUNCTION unknown_email_ids(integer) RETURNS SETOF integer AS $$
DECLARE
	pros text[];
BEGIN
	SELECT profiles INTO pros FROM emailers WHERE id = $1;
	IF pros = array['ALL'] THEN
		RETURN QUERY SELECT id FROM emails WHERE person_id IS NULL ORDER BY id;
	ELSE
		RETURN QUERY SELECT id FROM emails WHERE person_id IS NULL
			 AND profile = ANY(pros) ORDER BY id;
	END IF;
END;
$$ LANGUAGE plpgsql;

