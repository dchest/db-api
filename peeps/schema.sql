SET client_min_messages TO ERROR;
SET client_encoding = 'UTF8';
DROP SCHEMA IF EXISTS peeps CASCADE;
BEGIN;

CREATE SCHEMA peeps;
SET search_path = peeps;

-- Country codes used mainly for foreign key constraint on people.country
-- From http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2 - data loaded below
-- No need for any API to update, insert, or delete from this table.
CREATE TABLE countries (
	code character(2) NOT NULL primary key,
	name text
);

CREATE TABLE currencies (
	code character(3) NOT NULL primary key,
	name text,
	rate numeric
);

-- Big master table for people
CREATE TABLE people (
	id serial primary key,
	email varchar(127) UNIQUE CONSTRAINT valid_email CHECK (email ~ '\A\S+@\S+\.\S+\Z'),
	name varchar(127) NOT NULL CONSTRAINT no_name CHECK (LENGTH(name) > 0),
	address varchar(64), --  not mailing address, but "how do I address you?".  Usually firstname.
	hashpass varchar(72), -- user-chosen password, blowfish crypted using set_hashpass function below.
	lopass char(4), -- random used with id for low-security unsubscribe links to deter id spoofing
	newpass char(8) UNIQUE, -- random for "forgot my password" emails, erased when set_hashpass
	company varchar(127),
	city varchar(32),
	state varchar(16),
	postalcode varchar(12),
	country char(2) REFERENCES countries(code),
	phone varchar(18),
	notes text,
	email_count integer not null default 0,
	listype varchar(4),
	categorize_as varchar(16), -- if not null, incoming emails.category set to this
	created_at date not null default CURRENT_DATE
);
CREATE INDEX person_name ON people(name);

-- People authorized to answer/create emails
CREATE TABLE emailers (
	id serial primary key,
	person_id integer NOT NULL UNIQUE REFERENCES people(id) ON DELETE RESTRICT,
	admin boolean NOT NULL DEFAULT 'f',
	profiles text[] NOT NULL DEFAULT '{}',  -- only allowed to view these emails.profile
	categories text[] NOT NULL DEFAULT '{}' -- only allowed to view these emails.category
);

-- Catch-all for any random facts about this person
CREATE TABLE userstats (
	id serial primary key,
	person_id integer not null REFERENCES people(id) ON DELETE CASCADE,
	statkey varchar(32) not null CONSTRAINT statkey_format CHECK (statkey ~ '\A[a-z0-9._-]+\Z'),
	statvalue text not null CONSTRAINT statval_not_empty CHECK (length(statvalue) > 0),
	created_at date not null default CURRENT_DATE
);
CREATE INDEX userstats_person ON userstats(person_id);
CREATE INDEX userstats_statkey ON userstats(statkey);

-- This person's websites
CREATE TABLE urls (
	id serial primary key,
	person_id integer not null REFERENCES people(id) ON DELETE CASCADE,
	url varchar(255) CONSTRAINT url_format CHECK (url ~ '^https?://[0-9a-zA-Z_-]+\.[a-zA-Z0-9]+'),
	main boolean  -- means it's their main/home site
);
CREATE INDEX urls_person ON urls(person_id);

-- Logged-in users given a cookie with random string, to look up their person_id
CREATE TABLE logins (
	person_id integer not null REFERENCES people(id) ON DELETE CASCADE,
	cookie_id char(32) not null,
	cookie_tok char(32) not null,
	cookie_exp integer not null,
	domain varchar(32) not null,
	last_login date not null default CURRENT_DATE,
	ip varchar(15),
	PRIMARY KEY (cookie_id, cookie_tok)
);
CREATE INDEX logins_person_id ON logins(person_id);

-- All incoming and outgoing emails
CREATE TABLE emails (
	id serial primary key,
	person_id integer REFERENCES people(id),
	profile varchar(18) not null CHECK (length(profile) > 0),  -- which email address sent to/from
	category varchar(16) not null CHECK (length(category) > 0),  -- like gmail's labels, but 1-to-1
	created_at timestamp without time zone not null DEFAULT current_timestamp,
	created_by integer REFERENCES emailers(id),
	opened_at timestamp without time zone,
	opened_by integer REFERENCES emailers(id),
	closed_at timestamp without time zone,
	closed_by integer REFERENCES emailers(id),
	reference_id integer REFERENCES emails(id) DEFERRABLE, -- email this is replying to
	answer_id integer REFERENCES emails(id) DEFERRABLE, -- email replying to this one
	their_email varchar(127) NOT NULL CONSTRAINT valid_email CHECK (their_email ~ '\A\S+@\S+\.\S+\Z'),  -- their email address (whether incoming or outgoing)
	their_name varchar(127) NOT NULL,
	subject varchar(127),
	headers text,
	body text,
	message_id varchar(255) UNIQUE,
	outgoing boolean default 'f',
	flag integer  -- rarely used, to mark especially important emails 
);
CREATE INDEX emails_person_id ON emails(person_id);
CREATE INDEX emails_category ON emails(category);
CREATE INDEX emails_profile ON emails(profile);
CREATE INDEX emails_created_by ON emails(created_by);
CREATE INDEX emails_opened_by ON emails(opened_by);
CREATE INDEX emails_outgoing ON emails(outgoing);

-- Attachments sent with incoming emails
CREATE TABLE email_attachments (
	id serial primary key,
	email_id integer REFERENCES emails(id) ON DELETE CASCADE,
	mime_type text,
	filename text,
	bytes integer
);
CREATE INDEX email_attachments_email_id ON email_attachments(email_id);

-- Commonly used emails.body templates
CREATE TABLE formletters (
	id serial primary key,
	title varchar(64) UNIQUE,
	explanation varchar(255),
	body text,
	created_at date not null default CURRENT_DATE
);

-- Users given direct API access
CREATE TABLE api_keys (
	person_id integer NOT NULL UNIQUE REFERENCES people(id) ON DELETE CASCADE,
	akey char(8) NOT NULL UNIQUE,
	apass char(8) NOT NULL,
	apis text[] NOT NULL DEFAULT '{}',  -- can only access these APIs
	PRIMARY KEY (akey, apass)
);

COMMIT;


----------------------------------------
--------------- VIEWS FOR JSON RESPONSES:
----------------------------------------

DROP VIEW IF EXISTS people_view CASCADE;
CREATE VIEW people_view AS
	SELECT id, name, email, email_count FROM people;

DROP VIEW IF EXISTS person_view CASCADE;
CREATE VIEW person_view AS
	SELECT id, name, address, email, company, city, state, country, notes, phone, 
		listype, categorize_as, created_at,
		(SELECT json_agg(s) AS stats FROM
			(SELECT id, created_at, statkey AS name, statvalue AS value
				FROM userstats WHERE person_id=people.id ORDER BY id) s),
		(SELECT json_agg(u) AS urls FROM
			(SELECT id, url, main FROM urls WHERE person_id=people.id
				ORDER BY main DESC NULLS LAST, id) u),
		(SELECT json_agg(e) AS emails FROM
			(SELECT id, created_at, subject, outgoing FROM emails
				WHERE person_id=people.id ORDER BY id) e)
		FROM people;

DROP VIEW IF EXISTS emails_view CASCADE;
CREATE VIEW emails_view AS
	SELECT id, subject, created_at, their_name, their_email FROM emails;

DROP VIEW IF EXISTS emails_full_view CASCADE;
CREATE VIEW emails_full_view AS
	SELECT id, message_id, profile, category, created_at, opened_at, closed_at,
		their_email, their_name, subject, headers, body, outgoing, person_id
		FROM emails;

DROP VIEW IF EXISTS email_view CASCADE;
CREATE VIEW email_view AS
	SELECT id, profile, category,
		created_at, (SELECT row_to_json(p1) AS creator FROM
			(SELECT emailers.id, people.name FROM emailers
				JOIN people ON emailers.person_id=people.id
				WHERE emailers.id = created_by) p1),
		opened_at, (SELECT row_to_json(p2) AS openor FROM
			(SELECT emailers.id, people.name FROM emailers
				JOIN people ON emailers.person_id=people.id
				WHERE emailers.id = opened_by) p2),
		closed_at, (SELECT row_to_json(p3) AS closor FROM
			(SELECT emailers.id, people.name FROM emailers
				JOIN people ON emailers.person_id=people.id
				WHERE emailers.id = closed_by) p3),
		message_id, outgoing, reference_id, answer_id,
		their_email, their_name, headers, subject, body,
		(SELECT json_agg(a) AS attachments FROM
			(SELECT id, filename FROM email_attachments WHERE email_id=emails.id) a),
		(SELECT row_to_json(p) AS person FROM
			(SELECT * FROM person_view WHERE id = person_id) p)
		FROM emails;

DROP VIEW IF EXISTS unknown_view CASCADE;
CREATE VIEW unknown_view AS
	SELECT id, their_email, their_name, headers, subject, body FROM emails;

DROP VIEW IF EXISTS formletters_view CASCADE;
CREATE VIEW formletters_view AS
	SELECT id, title, explanation, created_at FROM formletters;

DROP VIEW IF EXISTS formletter_view CASCADE;
CREATE VIEW formletter_view AS
	SELECT id, title, explanation, body, created_at FROM formletters;

DROP VIEW IF EXISTS stats_view CASCADE;
CREATE VIEW stats_view AS
	SELECT userstats.id, userstats.created_at, statkey AS name, statvalue AS value,
		(SELECT row_to_json(p) FROM
			(SELECT people.id, people.name, people.email) p) AS person
		FROM userstats LEFT JOIN people ON userstats.person_id=people.id
		ORDER BY userstats.id DESC;

----------------------------
----------- peeps FUNCTIONS:
---- (many just generic use)
----------------------------

-- pgcrypto for people.hashpass
CREATE OR REPLACE FUNCTION crypt(text, text) RETURNS text AS '$libdir/pgcrypto', 'pg_crypt' LANGUAGE c IMMUTABLE STRICT;
CREATE OR REPLACE FUNCTION gen_salt(text, integer) RETURNS text AS '$libdir/pgcrypto', 'pg_gen_salt_rounds' LANGUAGE c STRICT;


-- used by other functions, below, for any random strings needed
CREATE OR REPLACE FUNCTION random_string(length integer) RETURNS text AS $$
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
CREATE OR REPLACE FUNCTION unique_for_table_field(str_len integer, table_name text, field_name text) RETURNS text AS $$
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
CREATE OR REPLACE FUNCTION tables_referencing(my_schema text, my_table text, my_column text) RETURNS text[] AS $$
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


-- RETURNS: array of column names that ARE allowed to be updated
-- PARAMS: schema name, table name, array of col names NOT allowed to be updated
CREATE OR REPLACE FUNCTION cols2update(text, text, text[]) RETURNS text[] AS $$
BEGIN
	RETURN array(SELECT column_name::text FROM information_schema.columns
		WHERE table_schema=$1 AND table_name=$2 AND column_name != ALL($3));
END;
$$ LANGUAGE plpgsql;


-- PARAMS: table name, id, json, array of cols that ARE allowed to be updated
CREATE OR REPLACE FUNCTION jsonupdate(text, integer, json, text[]) RETURNS VOID AS $$
DECLARE
	col record;
BEGIN
	FOR col IN SELECT name FROM json_object_keys($3) AS name LOOP
		CONTINUE WHEN col.name != ALL($4);
		EXECUTE format ('UPDATE %s SET %I =
			(SELECT %I FROM json_populate_record(null::%s, $1)) WHERE id = %L',
			$1, col.name, col.name, $1, $2) USING $3;
	END LOOP;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: any text that needs to be stripped of HTML tags
CREATE OR REPLACE FUNCTION strip_tags(text) RETURNS text AS $$
BEGIN
	RETURN regexp_replace($1 , '</?[^>]+?>', '', 'g');
END;
$$ LANGUAGE plpgsql;


-- PARAMS: any text that needs HTML escape
CREATE OR REPLACE FUNCTION escape_html(text) RETURNS text AS $$
DECLARE
	nu text;
BEGIN
	nu := replace($1, '&', '&amp;');
	nu := replace(nu, '''', '&#39;');
	nu := replace(nu, '"', '&quot;');
	nu := replace(nu, '<', '&lt;');
	nu := replace(nu, '>', '&gt;');
	RETURN nu;
END;
$$ LANGUAGE plpgsql;


-- Use this to add a new person to the database.  Ensures unique email without clash.
-- USAGE: SELECT * FROM person_create('Dude Abides', 'dude@abid.es');
-- Will always return peeps.people row, whether new INSERT or existing SELECT
CREATE OR REPLACE FUNCTION person_create(new_name text, new_email text) RETURNS SETOF peeps.people AS $$
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
-- USAGE: SELECT set_hashpass(123, 'Th€IR nü FunK¥(!) pá$$werđ');
-- Returns false if that peeps.people.id doesn't exist, otherwise true.
CREATE OR REPLACE FUNCTION set_hashpass(person_id integer, password text) RETURNS boolean AS $$
BEGIN
	IF password IS NULL OR length(btrim(password)) < 4 THEN
		RAISE 'short_password';
	END IF;
	UPDATE peeps.people SET newpass=NULL,
		hashpass=peeps.crypt(password, peeps.gen_salt('bf', 8)) WHERE id = person_id;
	IF FOUND THEN
		RETURN true;
	ELSE
		RETURN false;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- For signups where new user gives name, email, AND password at once.
-- Don't want to set password if email already exists in system, otherwise attacker
-- could use it to change someone's password. So check existence first, then create.
-- PARAMS: name, email, password
CREATE OR REPLACE FUNCTION person_create_pass(text, text, text) RETURNS SETOF peeps.people AS $$
DECLARE
	clean_email text;
	pid integer;
BEGIN
	clean_email := lower(regexp_replace($2, '\s', '', 'g'));
	IF clean_email IS NULL OR clean_email = '' THEN
		RAISE 'missing_email';
	END IF;
	IF EXISTS (SELECT 1 FROM peeps.people WHERE email = clean_email) THEN
		RAISE 'exists';
	END IF;
	SELECT id INTO pid FROM peeps.person_create($1, $2);
	PERFORM peeps.set_hashpass(pid, $3);
	RETURN QUERY SELECT * FROM peeps.people WHERE id = pid;
END;
$$ LANGUAGE plpgsql;


-- Use this when a user is logging in with their email and (their own chosen) password.
-- USAGE: SELECT * FROM person_email_pass('dude@abid.es', 'Th€IR öld FunK¥ pá$$werđ');
-- Returns peeps.people.* if both are correct, or nothing if not.
-- Once authorized here, give logins or api_key cookie for future lookups.
CREATE OR REPLACE FUNCTION person_email_pass(my_email text, my_pass text) RETURNS SETOF peeps.people AS $$
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
	RETURN QUERY SELECT * FROM peeps.people WHERE email=clean_email AND hashpass=peeps.crypt(my_pass, hashpass);
END;
$$ LANGUAGE plpgsql;


-- When a person has multiple entries in peeps.people, merge two into one, updating foreign keys.
-- USAGE: SELECT person_merge_from_to(5432, 4321);
-- Returns array of tables actually updated in schema.table format like {'muckwork.clients', 'sivers.comments'}
-- (Return value is probably unneeded, but here it is anyway, just in case.)
CREATE OR REPLACE FUNCTION person_merge_from_to(old_id integer, new_id integer) RETURNS text[] AS $$
DECLARE
	done_tables text[] := ARRAY[]::text[];
	a_table text;
	rowcount integer;
	old_p peeps.people;
	new_p peeps.people;
BEGIN
	-- update ids to point to new one
	FOREACH a_table IN ARRAY peeps.tables_referencing('peeps', 'people', 'id') LOOP
		EXECUTE format ('UPDATE %s SET person_id=%s WHERE person_id=%s',
			a_table, new_id, old_id);
		GET DIAGNOSTICS rowcount = ROW_COUNT;
		IF rowcount > 0 THEN
			done_tables := done_tables || a_table;
		END IF;
	END LOOP;
	-- copy better(longer) data from old to new
	-- company, city, state, postalcode, country, phone, categorize_as
	SELECT * INTO old_p FROM peeps.people WHERE id = old_id;
	SELECT * INTO new_p FROM peeps.people WHERE id = new_id;
	IF COALESCE(LENGTH(old_p.company), 0) > COALESCE(LENGTH(new_p.company), 0) THEN
		UPDATE peeps.people SET company = old_p.company WHERE id = new_id;
	END IF;
	IF COALESCE(LENGTH(old_p.city), 0) > COALESCE(LENGTH(new_p.city), 0) THEN
		UPDATE peeps.people SET city = old_p.city WHERE id = new_id;
	END IF;
	IF COALESCE(LENGTH(old_p.state), 0) > COALESCE(LENGTH(new_p.state), 0) THEN
		UPDATE peeps.people SET state = old_p.state WHERE id = new_id;
	END IF;
	IF COALESCE(LENGTH(old_p.postalcode), 0) > COALESCE(LENGTH(new_p.postalcode), 0) THEN
		UPDATE peeps.people SET postalcode = old_p.postalcode WHERE id = new_id;
	END IF;
	IF COALESCE(LENGTH(old_p.country), 0) > COALESCE(LENGTH(new_p.country), 0) THEN
		UPDATE peeps.people SET country = old_p.country WHERE id = new_id;
	END IF;
	IF COALESCE(LENGTH(old_p.phone), 0) > COALESCE(LENGTH(new_p.phone), 0) THEN
		UPDATE peeps.people SET phone = old_p.phone WHERE id = new_id;
	END IF;
	IF COALESCE(LENGTH(old_p.categorize_as), 0) > COALESCE(LENGTH(new_p.categorize_as), 0) THEN
		UPDATE peeps.people SET categorize_as = old_p.categorize_as WHERE id = new_id;
	END IF;
	IF LENGTH(old_p.notes) > 0 THEN  -- combine notes
		UPDATE peeps.people SET notes = CONCAT(old_p.notes, E'\n', notes) WHERE id = new_id;
	END IF;
	-- Done! delete old one
	DELETE FROM peeps.people WHERE id = old_id;
	RETURN done_tables;
END;
$$ LANGUAGE plpgsql;


-- Returns emails.* only if emailers.profiles && emailers.cateories matches
CREATE OR REPLACE FUNCTION emailer_get_email(emailer_id integer, email_id integer) RETURNS SETOF peeps.emails AS $$
DECLARE
	emailer peeps.emailers;
	email peeps.emails;
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
CREATE OR REPLACE FUNCTION emailer_get_unopened(emailer_id integer) RETURNS SETOF peeps.emails AS $$
DECLARE
	qry text := 'SELECT * FROM peeps.emails WHERE opened_at IS NULL AND person_id IS NOT NULL';
	emailer peeps.emailers;
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
CREATE OR REPLACE FUNCTION login_person_domain(my_person_id integer, my_domain char, OUT cookie text) RETURNS text AS $$
DECLARE
	c_id text;
	c_tok text;
	c_exp integer;
BEGIN
	c_id := md5(my_domain || md5(my_person_id::char)); -- also in get_person_from_cookie
	c_tok := random_string(32);
	c_exp := FLOOR(EXTRACT(epoch from (NOW() + interval '1 year')));
	INSERT INTO peeps.logins(person_id, cookie_id, cookie_tok, cookie_exp, domain) VALUES (my_person_id, c_id, c_tok, c_exp, my_domain);
	cookie := CONCAT(c_id, ':', c_tok);
END;
$$ LANGUAGE plpgsql;


-- Give the cookie value returned from login_person_domain, and I'll return people.* if found and not expired
CREATE OR REPLACE FUNCTION get_person_from_cookie(cookie char) RETURNS SETOF peeps.people AS $$
DECLARE
	c_id text;
	c_tok text;
	a_login peeps.logins;
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
CREATE OR REPLACE FUNCTION unopened_email_ids(integer) RETURNS SETOF integer AS $$
DECLARE
	pros text[];
	cats text[];
BEGIN
	SELECT profiles, categories INTO pros, cats FROM peeps.emailers WHERE id = $1;
	IF pros = array['ALL'] AND cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM peeps.emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL ORDER BY id;
	ELSIF cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM peeps.emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL AND profile = ANY(pros) ORDER BY id;
	ELSIF pros = array['ALL'] THEN
		RETURN QUERY SELECT id FROM peeps.emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL AND category = ANY(cats) ORDER BY id;
	ELSE
		RETURN QUERY SELECT id FROM peeps.emails WHERE opened_by IS NULL
			AND person_id IS NOT NULL
			AND profile = ANY(pros) AND category = ANY(cats) ORDER BY id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- ids of already-open emails this emailer is allowed to access
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION opened_email_ids(integer) RETURNS SETOF integer AS $$
DECLARE
	pros text[];
	cats text[];
BEGIN
	SELECT profiles, categories INTO pros, cats FROM peeps.emailers WHERE id = $1;
	IF pros = array['ALL'] AND cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM peeps.emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL ORDER BY id;
	ELSIF cats = array['ALL'] THEN
		RETURN QUERY SELECT id FROM peeps.emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL AND profile = ANY(pros) ORDER BY id;
	ELSIF pros = array['ALL'] THEN
		RETURN QUERY SELECT id FROM peeps.emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL AND category = ANY(cats) ORDER BY id;
	ELSE
		RETURN QUERY SELECT id FROM peeps.emails WHERE opened_by IS NOT NULL
			AND closed_at IS NULL
			AND profile = ANY(pros) AND category = ANY(cats) ORDER BY id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- ids of unknown-person emails, if this emailer is admin or allowed
-- (unknown-person emails don't have categories, so not checking for that)
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION unknown_email_ids(integer) RETURNS SETOF integer AS $$
DECLARE
	pros text[];
BEGIN
	SELECT profiles INTO pros FROM peeps.emailers WHERE id = $1;
	IF pros = array['ALL'] THEN
		RETURN QUERY SELECT id FROM peeps.emails WHERE person_id IS NULL ORDER BY id;
	ELSE
		RETURN QUERY SELECT id FROM peeps.emails WHERE person_id IS NULL
			 AND profile = ANY(pros) ORDER BY id;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- If this emailer is allowed to see this email,
-- Returns email.id if found and permission granted, NULL if not
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION ok_email(integer, integer) RETURNS integer AS $$
DECLARE
	pros text[];
	cats text[];
	eid integer;
BEGIN
	SELECT profiles, categories INTO pros, cats FROM peeps.emailers WHERE id = $1;
	IF pros = array['ALL'] AND cats = array['ALL'] THEN
		SELECT id INTO eid FROM peeps.emails WHERE id = $2;
	ELSIF cats = array['ALL'] THEN
		SELECT id INTO eid FROM peeps.emails WHERE id = $2 AND profile = ANY(pros);
	ELSIF pros = array['ALL'] THEN
		SELECT id INTO eid FROM peeps.emails WHERE id = $2 AND category = ANY(cats);
	ELSE
		SELECT id INTO eid FROM peeps.emails WHERE id = $2
			AND profile = ANY(pros) AND category = ANY(cats);
	END IF;
	RETURN eid;
END;
$$ LANGUAGE plpgsql;


-- Update it to be shown as opened_by this emailer now (if not already open)
-- Returns email.id if found and permission granted, NULL if not
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION open_email(integer, integer) RETURNS integer AS $$
DECLARE
	ok_id integer;
BEGIN
	ok_id := ok_email($1, $2);
	IF ok_id IS NOT NULL THEN
		UPDATE peeps.emails SET opened_at=NOW(), opened_by=$1
			WHERE id=ok_id AND opened_by IS NULL;
	END IF;
	RETURN ok_id;
END;
$$ LANGUAGE plpgsql;


-- Create a new outging email
-- PARAMS: emailer_id, person_id, profile, category, subject, body, reference_id (NULL unless reply)
CREATE OR REPLACE FUNCTION outgoing_email(integer, integer, text, text, text, text, integer) RETURNS integer AS $$
DECLARE
	p peeps.people;
	rowcount integer;
	e peeps.emails;
	greeting text;
	signature text;
	new_body text;
	opt_headers text;
	old_body text;
	new_id integer;
BEGIN
	-- VERIFY INPUT:
	SELECT * INTO p FROM peeps.people WHERE id = $2;
	GET DIAGNOSTICS rowcount = ROW_COUNT;
	IF rowcount = 0 THEN
		RAISE 'person_id not found';
	END IF;
	CASE $3 WHEN 'we@woodegg' THEN
		signature := 'Wood Egg  we@woodegg.com  http://woodegg.com/';
	WHEN 'derek@sivers' THEN
		signature := 'Derek Sivers  derek@sivers.org  http://sivers.org/';
	ELSE
		RAISE 'invalid profile';
	END CASE;
	IF $4 IS NULL OR (regexp_replace($4, '\s', '', 'g') = '') THEN
		RAISE 'category must not be empty';
	END IF;
	IF $5 IS NULL OR (regexp_replace($5, '\s', '', 'g') = '') THEN
		RAISE 'subject must not be empty';
	END IF;
	IF $6 IS NULL OR (regexp_replace($6, '\s', '', 'g') = '') THEN
		RAISE 'body must not be empty';
	END IF;
	IF $7 IS NOT NULL THEN SELECT
		CONCAT('References: <', message_id, E'>\nIn-Reply-To: <', message_id, '>'),
		CONCAT(E'\n\n', regexp_replace(body, '^', '> ', 'ng'))
		INTO opt_headers, old_body FROM peeps.emails WHERE id = $7;
	END IF;
	-- START CREATING EMAIL:
	greeting := concat('Hi ', p.address);
	new_body := concat(greeting, E' -\n\n', $6, E'\n\n--\n', signature, old_body);
	EXECUTE 'INSERT INTO peeps.emails (person_id, outgoing, their_email, their_name,'
		|| ' created_at, created_by, opened_at, opened_by, closed_at, closed_by,'
		|| ' profile, category, subject, body, headers, reference_id) VALUES'
		|| ' ($1, NULL, $2, $3,'  -- outgoing = NULL = queued for sending
		|| ' NOW(), $4, NOW(), $5, NOW(), $6,'
		|| ' $7, $8, $9, $10, $11, $12) RETURNING id' INTO new_id
		USING p.id, p.email, p.name,
			$1, $1, $1,
			$3, $4, $5, new_body, opt_headers, $7;
	RETURN new_id;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: people.id, formletters.id
CREATE OR REPLACE FUNCTION parse_formletter_body(integer, integer) RETURNS text AS $$
DECLARE
	new_body text;
	thisvar text;
	thisval text;
BEGIN
	SELECT body INTO new_body FROM peeps.formletters WHERE id = $2;
	FOR thisvar IN SELECT regexp_matches(body, '{([^}]+)}', 'g') FROM peeps.formletters
		WHERE id = $2 LOOP
		EXECUTE format ('SELECT %s::text FROM peeps.people WHERE id=%L',
			btrim(thisvar, '{}'), $1) INTO thisval;
		new_body := regexp_replace(new_body, thisvar, thisval);
	END LOOP;
	RETURN new_body;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: email, password
CREATE OR REPLACE FUNCTION pid_from_email_pass(text, text, OUT pid integer) AS $$
DECLARE
	clean_email text;
BEGIN
	IF $1 IS NOT NULL AND $2 IS NOT NULL THEN
		clean_email := lower(regexp_replace($1, '\s', '', 'g'));
		IF clean_email ~ '\A\S+@\S+\.\S+\Z' AND LENGTH($2) > 3 THEN
			SELECT id INTO pid FROM peeps.people
				WHERE email=clean_email AND hashpass=peeps.crypt($2, hashpass);
		END IF;
	END IF;
END;
$$ LANGUAGE plpgsql;

-- Strip spaces and lowercase email address before validating & storing
CREATE OR REPLACE FUNCTION clean_email() RETURNS TRIGGER AS $$
BEGIN
	NEW.email = lower(regexp_replace(NEW.email, '\s', '', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_email ON peeps.people CASCADE;
CREATE TRIGGER clean_email BEFORE INSERT OR UPDATE OF email ON peeps.people FOR EACH ROW EXECUTE PROCEDURE clean_email();


CREATE OR REPLACE FUNCTION clean_their_email() RETURNS TRIGGER AS $$
BEGIN
	NEW.their_name = peeps.strip_tags(btrim(regexp_replace(NEW.their_name, '\s+', ' ', 'g')));
	NEW.their_email = lower(regexp_replace(NEW.their_email, '\s', '', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_their_email ON peeps.emails CASCADE;
CREATE TRIGGER clean_their_email BEFORE INSERT OR UPDATE OF their_name, their_email ON peeps.emails FOR EACH ROW EXECUTE PROCEDURE clean_their_email();


-- Strip all line breaks and spaces around name before storing
CREATE OR REPLACE FUNCTION clean_name() RETURNS TRIGGER AS $$
BEGIN
	NEW.name = peeps.strip_tags(btrim(regexp_replace(NEW.name, '\s+', ' ', 'g')));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_name ON peeps.people CASCADE;
CREATE TRIGGER clean_name BEFORE INSERT OR UPDATE OF name ON peeps.people FOR EACH ROW EXECUTE PROCEDURE clean_name();


-- Statkey has no whitespace at all. Statvalue trimmed but keeps inner whitespace.
CREATE OR REPLACE FUNCTION clean_userstats() RETURNS TRIGGER AS $$
BEGIN
	NEW.statkey = lower(regexp_replace(NEW.statkey, '[^[:alnum:]._-]', '', 'g'));
	IF NEW.statkey = '' THEN
		RAISE 'stats.key must not be empty';
	END IF;
	NEW.statvalue = btrim(NEW.statvalue, E'\r\n\t ');
	IF NEW.statvalue = '' THEN
		RAISE 'stats.value must not be empty';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_userstats ON peeps.userstats CASCADE;
CREATE TRIGGER clean_userstats BEFORE INSERT OR UPDATE OF statkey, statvalue ON peeps.userstats FOR EACH ROW EXECUTE PROCEDURE clean_userstats();


-- urls.url remove all whitespace, then add http:// if not there
CREATE OR REPLACE FUNCTION clean_url() RETURNS TRIGGER AS $$
BEGIN
	NEW.url = regexp_replace(NEW.url, '\s', '', 'g');
	IF NEW.url !~ '^https?://' THEN
		NEW.url = 'http://' || NEW.url;
	END IF;
	IF NEW.url !~ '^https?://[0-9a-zA-Z_-]+\.[a-zA-Z0-9]+' THEN
		RAISE 'bad url';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_url ON peeps.urls CASCADE;
CREATE TRIGGER clean_url BEFORE INSERT OR UPDATE OF url ON peeps.urls FOR EACH ROW EXECUTE PROCEDURE clean_url();


-- Create "address" (first word of name) and random password upon insert of new person
CREATE OR REPLACE FUNCTION generated_person_fields() RETURNS TRIGGER AS $$
BEGIN
	NEW.address = split_part(btrim(regexp_replace(NEW.name, '\s+', ' ', 'g')), ' ', 1);
	NEW.lopass = peeps.random_string(4);
	NEW.newpass = peeps.unique_for_table_field(8, 'peeps.people', 'newpass');
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS generate_person_fields ON peeps.people CASCADE;
CREATE TRIGGER generate_person_fields BEFORE INSERT ON peeps.people FOR EACH ROW EXECUTE PROCEDURE generated_person_fields();


-- If something sets any of these fields to '', change it to NULL before saving
CREATE OR REPLACE FUNCTION null_person_fields() RETURNS TRIGGER AS $$
BEGIN
	IF btrim(NEW.country) = '' THEN
		NEW.country = NULL;
	END IF;
	IF btrim(NEW.email) = '' THEN
		NEW.email = NULL;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS null_person_fields ON peeps.people CASCADE;
CREATE TRIGGER null_person_fields BEFORE INSERT OR UPDATE OF country, email ON peeps.people FOR EACH ROW EXECUTE PROCEDURE null_person_fields();


-- No whitespace, all lowercase, for emails.profile and emails.category
CREATE OR REPLACE FUNCTION clean_emails_fields() RETURNS TRIGGER AS $$
BEGIN
	NEW.profile = regexp_replace(lower(NEW.profile), '[^[:alnum:]_@-]', '', 'g');
	IF TG_OP = 'INSERT' AND (NEW.category IS NULL OR trim(both ' ' from NEW.category) = '') THEN
		NEW.category = NEW.profile;
	ELSE
		NEW.category = regexp_replace(lower(NEW.category), '[^[:alnum:]_@-]', '', 'g');
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_emails_fields ON peeps.emails CASCADE;
CREATE TRIGGER clean_emails_fields BEFORE INSERT OR UPDATE OF profile, category ON peeps.emails FOR EACH ROW EXECUTE PROCEDURE clean_emails_fields();


-- Update people.email_count when number of emails for this person_id changes
CREATE OR REPLACE FUNCTION update_email_count() RETURNS TRIGGER AS $$
DECLARE
	pid integer := NULL;
BEGIN
	IF ((TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.person_id IS NOT NULL) THEN
		pid := NEW.person_id;
	ELSIF (TG_OP = 'UPDATE' AND OLD.person_id IS NOT NULL) THEN
		pid := OLD.person_id;  -- in case updating to set person_id = NULL, recalcuate old one
	ELSIF (TG_OP = 'DELETE' AND OLD.person_id IS NOT NULL) THEN
		pid := OLD.person_id;
	END IF;
	IF pid IS NOT NULL THEN
		UPDATE peeps.people SET email_count=(SELECT COUNT(*) FROM peeps.emails WHERE person_id = pid) WHERE id = pid;
	END IF;
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS update_email_count ON peeps.emails CASCADE;
CREATE TRIGGER update_email_count AFTER INSERT OR DELETE OR UPDATE OF person_id ON peeps.emails FOR EACH ROW EXECUTE PROCEDURE update_email_count();


-- Setting a URL to be the "main" one sets all other URLs for that person to be NOT main
CREATE OR REPLACE FUNCTION one_main_url() RETURNS TRIGGER AS $$
BEGIN
	IF NEW.main = 't' THEN
		UPDATE peeps.urls SET main=FALSE WHERE person_id=NEW.person_id AND id != NEW.id;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS one_main_url ON peeps.urls CASCADE;
CREATE TRIGGER one_main_url AFTER INSERT OR UPDATE OF main ON peeps.urls FOR EACH ROW EXECUTE PROCEDURE one_main_url();


-- Generate random strings when creating new api_key
CREATE OR REPLACE FUNCTION generated_api_keys() RETURNS TRIGGER AS $$
BEGIN
	NEW.akey = peeps.unique_for_table_field(8, 'peeps.api_keys', 'akey');
	NEW.apass = peeps.random_string(8);
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS generated_api_keys ON peeps.api_keys CASCADE;
CREATE TRIGGER generated_api_keys BEFORE INSERT ON peeps.api_keys FOR EACH ROW EXECUTE PROCEDURE generated_api_keys();


-- generate message_id for outgoing emails
CREATE OR REPLACE FUNCTION make_message_id() RETURNS TRIGGER AS $$
BEGIN
	IF NEW.message_id IS NULL AND (NEW.outgoing IS TRUE OR NEW.outgoing IS NULL) THEN
		NEW.message_id = CONCAT(
			to_char(current_timestamp, 'YYYYMMDDHH24MISSMS'),
			'.', NEW.person_id, '@sivers.org');
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS make_message_id ON peeps.emails CASCADE;
CREATE TRIGGER make_message_id BEFORE INSERT ON peeps.emails FOR EACH ROW EXECUTE PROCEDURE make_message_id();

----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

-- API REQUIRES AUTHENTICATION. User must be in peeps.emailers
-- peeps.emailers.id needed as first argument to many functions here

-- PARAMS: email, password, API_name
CREATE OR REPLACE FUNCTION auth_api(text, text, text, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM peeps.api_keys WHERE
			person_id=(SELECT id FROM peeps.person_email_pass($1, $2))
			AND $3=ANY(apis)) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- GET /emails/unopened/count
-- Grouped summary of howmany unopened emails in each profile/category
-- JSON format: {profiles:{categories:howmany}}
--{"derek@sivers":{"derek@sivers":43,"derek":2,"programmer":1},
-- "we@woodegg":{"woodeggRESEARCH":1,"woodegg":1,"we@woodegg":1}}
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION unopened_email_count(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_object_agg(profile, cats) FROM (WITH unopened AS
		(SELECT profile, category FROM peeps.emails WHERE id IN
			(SELECT * FROM peeps.unopened_email_ids($1)))
		SELECT profile, (SELECT json_object_agg(category, num) FROM
			(SELECT category, COUNT(*) AS num FROM unopened u2
				WHERE u2.profile=unopened.profile
				GROUP BY category ORDER BY num DESC) rr)
		AS cats FROM unopened GROUP BY profile) r;  
	IF js IS NULL THEN
		js := '{}';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/unopened/:profile/:category
-- PARAMS: emailer_id, profile, category
CREATE OR REPLACE FUNCTION unopened_emails(integer, text, text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.emails_view WHERE id IN
		(SELECT id FROM peeps.emails WHERE id IN (SELECT * FROM peeps.unopened_email_ids($1))
			AND profile = $2 AND category = $3) ORDER BY id) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /emails/next/:profile/:category
-- Opens email (updates status as opened by this emailer) then returns view
-- PARAMS: emailer_id, profile, category
CREATE OR REPLACE FUNCTION open_next_email(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	SELECT id INTO eid FROM peeps.emails
		WHERE id IN (SELECT * FROM peeps.unopened_email_ids($1))
		AND profile=$2 AND category=$3 ORDER BY id LIMIT 1;
	IF eid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		mime := 'application/json';
		PERFORM open_email($1, eid);
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/opened
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION opened_emails(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.emails_view WHERE id IN
		(SELECT * FROM peeps.opened_email_ids($1)) ORDER BY id) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/:id
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION get_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := open_email($1, $2);
	IF eid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id
-- PARAMS: emailer_id, email_id, JSON of new values
CREATE OR REPLACE FUNCTION update_email(integer, integer, json, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		PERFORM jsonupdate('peeps.emails', eid, $3,
			cols2update('peeps', 'emails', ARRAY['id', 'created_at']));
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- DELETE /emails/:id
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION delete_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
		DELETE FROM peeps.emails WHERE id = eid;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/close
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION close_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		UPDATE peeps.emails SET closed_at=NOW(), closed_by=$1 WHERE id = eid;
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/unread
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION unread_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		UPDATE peeps.emails SET opened_at=NULL, opened_by=NULL WHERE id = eid;
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/notme
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION not_my_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		UPDATE peeps.emails SET opened_at=NULL, opened_by=NULL, category=(SELECT
			substring(concat('not-', split_part(people.email,'@',1)) from 1 for 32)
			FROM peeps.emailers JOIN people ON emailers.person_id=people.id
			WHERE emailers.id = $1) WHERE id = eid;
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /emails/:id/reply?body=blah
-- PARAMS: emailer_id, email_id, body
CREATE OR REPLACE FUNCTION reply_to_email(integer, integer, text, OUT mime text, OUT js json) AS $$
DECLARE
	e emails;
	new_id integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	IF $3 IS NULL OR (regexp_replace($3, '\s', '', 'g') = '') THEN
		RAISE 'body must not be empty';
	END IF;
	SELECT * INTO e FROM peeps.emails WHERE id = ok_email($1, $2);
	IF e IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		-- PARAMS: emailer_id, person_id, profile, category, subject, body, reference_id 
		SELECT * INTO new_id FROM peeps.outgoing_email($1, e.person_id, e.profile, e.profile,
			concat('re: ', e.subject), $3, $2);
		UPDATE peeps.emails SET answer_id=new_id, closed_at=NOW(), closed_by=$1 WHERE id=$2;
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = new_id) r;
	END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- GET /unknowns/count
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION count_unknowns(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_build_object('count', (SELECT COUNT(*) FROM peeps.unknown_email_ids($1)));
END;
$$ LANGUAGE plpgsql;


-- GET /unknowns
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION get_unknowns(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.emails_view WHERE id IN
		(SELECT * FROM peeps.unknown_email_ids($1))) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /unknowns/next
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION get_next_unknown(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.unknown_view WHERE id IN
		(SELECT * FROM peeps.unknown_email_ids($1) LIMIT 1)) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /unknowns/:id?person_id=123 or 0 to create new
-- PARAMS: emailer_id, email_id, person_id
CREATE OR REPLACE FUNCTION set_unknown_person(integer, integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	this_e emails;
	newperson people;
	rowcount integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT * INTO this_e FROM peeps.emails WHERE id IN
		(SELECT * FROM peeps.unknown_email_ids($1)) AND id = $2;
	GET DIAGNOSTICS rowcount = ROW_COUNT;
	IF rowcount = 0 THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 RETURN; END IF;
	IF $3 = 0 THEN
		SELECT * INTO newperson FROM peeps.person_create(this_e.their_name, this_e.their_email);
	ELSE
		SELECT * INTO newperson FROM peeps.people WHERE id = $3;
		GET DIAGNOSTICS rowcount = ROW_COUNT;
		IF rowcount = 0 THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 RETURN; END IF;
		UPDATE peeps.people SET email=this_e.their_email,
			notes = concat('OLD EMAIL: ', email, E'\n', notes) WHERE id = $3;
	END IF;
	UPDATE peeps.emails SET person_id=newperson.id, category=profile WHERE id = $2;
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.email_view WHERE id = $2) r;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- DELETE /unknowns/:id
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION delete_unknown(integer, integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.unknown_view
		WHERE id IN (SELECT * FROM peeps.unknown_email_ids($1)) AND id = $2) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 RETURN;
	ELSE
		DELETE FROM peeps.emails WHERE id = $2;
	END IF;
END;
$$ LANGUAGE plpgsql;

COMMIT;


-- POST /people
-- PARAMS: name, email
CREATE OR REPLACE FUNCTION create_person(text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT id INTO pid FROM peeps.person_create($1, $2);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = pid) r;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/newpass
-- PARAMS: person_id
CREATE OR REPLACE FUNCTION make_newpass(integer, OUT mime text, OUT js json) AS $$
BEGIN
	UPDATE peeps.people
		SET newpass=peeps.unique_for_table_field(8, 'peeps.people', 'newpass')
		WHERE id=$1;
	IF FOUND THEN
		mime := 'application/json';
		js := json_build_object('id', $1);
	ELSE

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id
-- PARAMS: person_id
CREATE OR REPLACE FUNCTION get_person(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /people/:email
-- PARAMS: email
CREATE OR REPLACE FUNCTION get_person_email(text, OUT mime text, OUT js json) AS $$
DECLARE
	clean_email text;
BEGIN
	IF $1 IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
	clean_email := lower(regexp_replace($1, '\s', '', 'g'));
	IF clean_email !~ '\A\S+@\S+\.\S+\Z' THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE email = clean_email) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id/:lopass
-- PARAMS: person_id, lopass
CREATE OR REPLACE FUNCTION get_person_lopass(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT id INTO pid FROM peeps.people WHERE id=$1 AND lopass=$2;
	IF pid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		SELECT x.mime, x.js INTO mime, js FROM peeps.get_person($1) x;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id/:newpass
-- PARAMS: person_id, newpass
CREATE OR REPLACE FUNCTION get_person_newpass(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT id INTO pid FROM peeps.people WHERE id=$1 AND newpass=$2;
	IF pid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		SELECT x.mime, x.js INTO mime, js FROM peeps.get_person($1) x;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /people?email=&password=
-- PARAMS: email, password
CREATE OR REPLACE FUNCTION get_person_password(text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT p.pid INTO pid FROM peeps.pid_from_email_pass($1, $2) p;
	IF pid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		SELECT x.mime, x.js INTO mime, js FROM peeps.get_person(pid) x;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /person/{cookie}
-- PARAMS: cookie string
CREATE OR REPLACE FUNCTION get_person_cookie(text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT p.id INTO pid FROM peeps.get_person_from_cookie($1) p;
	IF pid IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		SELECT x.mime, x.js INTO mime, js FROM peeps.get_person(pid) x;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /login
-- PARAMS: person.id, domain
CREATE OR REPLACE FUNCTION cookie_from_id(integer, text, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT cookie FROM peeps.login_person_domain($1, $2)) r;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- POST /login
-- PARAMS: email, password, domain
CREATE OR REPLACE FUNCTION cookie_from_login(text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT p.pid INTO pid FROM peeps.pid_from_email_pass($1, $2) p;
	IF pid IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 ELSE
		SELECT x.mime, x.js INTO mime, js FROM peeps.cookie_from_id(pid, $3) x;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /people/:id/password
-- PARAMS: person_id, password
CREATE OR REPLACE FUNCTION set_password(integer, text, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	PERFORM peeps.set_hashpass($1, $2);
	SELECT x.mime, x.js INTO mime, js FROM peeps.get_person($1) x;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- PUT /people/:id
-- PARAMS: person_id, JSON of new values
CREATE OR REPLACE FUNCTION update_person(integer, json, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	PERFORM jsonupdate('peeps.people', $1, $2,
		cols2update('peeps', 'people', ARRAY['id', 'created_at']));
	SELECT x.mime, x.js INTO mime, js FROM peeps.get_person($1) x;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- DELETE /people/:id
-- PARAMS: person_id
CREATE OR REPLACE FUNCTION delete_person(integer, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		DELETE FROM peeps.people WHERE id = $1;
	END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;

-- POST /people/:id/urls
-- PARAMS: person_id, url
CREATE OR REPLACE FUNCTION add_url(integer, text, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	INSERT INTO urls(person_id, url) VALUES ($1, $2);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/stats
-- PARAMS: person_id, stat.name, stat.value
CREATE OR REPLACE FUNCTION add_stat(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	INSERT INTO userstats(person_id, statkey, statvalue) VALUES ($1, $2, $3);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/emails
-- PARAMS: emailer_id, person_id, profile, subject, body
CREATE OR REPLACE FUNCTION new_email(integer, integer, text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	new_id integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	-- PARAMS: emailer_id, person_id, profile, category, subject, body, reference_id (NULL unless reply)
	SELECT * INTO new_id FROM peeps.outgoing_email($1, $2, $3, $3, $4, $5, NULL);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.email_view WHERE id = new_id) r;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- GET /people/:id/emails
-- PARAMS: person_id
CREATE OR REPLACE FUNCTION get_person_emails(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM
		(SELECT * FROM peeps.emails_full_view WHERE person_id = $1 ORDER BY id) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/merge?id=old_id
-- PARAMS: person_id to KEEP, person_id to CHANGE
CREATE OR REPLACE FUNCTION merge_person(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	PERFORM person_merge_from_to($2, $1);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- GET /people/unmailed
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION people_unemailed(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view
		WHERE email_count = 0 ORDER BY id DESC LIMIT 200) r;
END;
$$ LANGUAGE plpgsql;


-- GET /search?q=term
-- PARAMS: search term
CREATE OR REPLACE FUNCTION people_search(text, OUT mime text, OUT js json) AS $$
DECLARE
	q text;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	q := concat('%', btrim($1, E'\t\r\n '), '%');
	IF LENGTH(q) < 4 THEN
		RAISE 'search term too short';
	END IF;
	mime := 'application/json';
	js := json_agg(r) FROM
		(SELECT * FROM peeps.people_view WHERE id IN (SELECT id FROM peeps.people
				WHERE name ILIKE q OR company ILIKE q OR email ILIKE q)
		ORDER BY email_count DESC, id DESC) r;
	IF js IS NULL THEN
		js := '{}';
	END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- GET /stats/:id
-- PARAMS: stats.id
CREATE OR REPLACE FUNCTION get_stat(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.stats_view WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;



-- PUT /stat/:id
-- PARAMS: stats.id, json
CREATE OR REPLACE FUNCTION update_stat(integer, json, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	PERFORM jsonupdate('peeps.userstats', $1, $2,
		cols2update('peeps', 'userstats', ARRAY['id', 'created_at']));
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.stats_view WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- DELETE /stats/:id
-- PARAMS: stats.id
CREATE OR REPLACE FUNCTION delete_stat(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.stats_view WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		DELETE FROM peeps.userstats WHERE id = $1;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /urls/:id
-- PARAMS: urls.id
CREATE OR REPLACE FUNCTION get_url(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.urls WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- DELETE /urls/:id
-- PARAMS: urls.id
CREATE OR REPLACE FUNCTION delete_url(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.urls WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		DELETE FROM peeps.urls WHERE id = $1;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /urls/:id
-- PARAMS: urls.id, JSON with allowed: person_id::int, url::text, main::boolean
CREATE OR REPLACE FUNCTION update_url(integer, json, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	PERFORM jsonupdate('peeps.urls', $1, $2,
		cols2update('peeps', 'urls', ARRAY['id']));
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.urls WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- GET /formletters
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION get_formletters(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM
		(SELECT * FROM peeps.formletters_view ORDER BY title) r;
END;
$$ LANGUAGE plpgsql;


-- POST /formletters
-- PARAMS: title
CREATE OR REPLACE FUNCTION create_formletter(text, OUT mime text, OUT js json) AS $$
DECLARE
	new_id integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	INSERT INTO formletters(title) VALUES ($1) RETURNING id INTO new_id;
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM peeps.formletter_view WHERE id = new_id) r;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- GET /formletters/:id
-- PARAMS: formletters.id
CREATE OR REPLACE FUNCTION get_formletter(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM peeps.formletter_view WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /formletters/:id
-- PARAMS: formletters.id, JSON keys: title, explanation, body
CREATE OR REPLACE FUNCTION update_formletter(integer, json, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	PERFORM jsonupdate('peeps.formletters', $1, $2,
		cols2update('peeps', 'formletters', ARRAY['id', 'created_at']));
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM peeps.formletter_view WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- DELETE /formletters/:id
-- PARAMS: formletters.id
CREATE OR REPLACE FUNCTION delete_formletter(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM peeps.formletter_view WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	ELSE
		DELETE FROM peeps.formletters WHERE id = $1;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- js = a simple JSON object: {"body": "The parsed text here, Derek."}
-- If wrong IDs given, value is null
-- GET /people/:id/formletters/:id
-- PARAMS: people.id, formletters.id
CREATE OR REPLACE FUNCTION parsed_formletter(integer, integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_build_object('body', parse_formletter_body($1, $2));
END;
$$ LANGUAGE plpgsql;


-- GET /locations
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION all_countries(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.countries ORDER BY name) r;
END;
$$ LANGUAGE plpgsql;


-- GET /country_names
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION country_names(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_object(
		ARRAY(SELECT code FROM countries ORDER BY code),
		ARRAY(SELECT name FROM countries ORDER BY code));
END;
$$ LANGUAGE plpgsql;


-- GET /countries
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION country_count(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT country, COUNT(*) FROM peeps.people
		WHERE country IS NOT NULL GROUP BY country ORDER BY COUNT(*) DESC, country) r;
END;
$$ LANGUAGE plpgsql;


-- GET /states/:country_code
-- PARAMS: 2-letter country code
CREATE OR REPLACE FUNCTION state_count(char(2), OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT state, COUNT(*) FROM peeps.people
		WHERE country = $1 AND state IS NOT NULL AND state != ''
		GROUP BY state ORDER BY COUNT(*) DESC, state) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /cities/:country_code/:state
-- PARAMS: 2-letter country code, state name
CREATE OR REPLACE FUNCTION city_count(char(2), text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT city, COUNT(*) FROM peeps.people
		WHERE country=$1 AND state=$2 AND (city IS NOT NULL AND city != '')
		GROUP BY city ORDER BY COUNT(*) DESC, city) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /cities/:country_code
-- PARAMS: 2-letter country code
CREATE OR REPLACE FUNCTION city_count(char(2), OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT city, COUNT(*) FROM peeps.people
		WHERE country=$1 AND (city IS NOT NULL AND city != '')
		GROUP BY city ORDER BY COUNT(*) DESC, city) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code
-- PARAMS: 2-letter country code
CREATE OR REPLACE FUNCTION people_from_country(char(2), OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code?state=XX
-- PARAMS: 2-letter country code, state
CREATE OR REPLACE FUNCTION people_from_state(char(2), text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1 AND state=$2)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code?city=XX
-- PARAMS: 2-letter country code, state
CREATE OR REPLACE FUNCTION people_from_city(char(2), text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1 AND city=$2)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code?city=XX&state=XX
-- PARAMS: 2-letter country code, state, city
CREATE OR REPLACE FUNCTION people_from_state_city(char(2), text, text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1 AND state=$2 AND city=$3)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;



-- GET /stats/:key/:value
-- PARAMS: stats.name, stats.value
CREATE OR REPLACE FUNCTION get_stats(text, text, OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.stats_view
		WHERE name = $1 AND value = $2) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /stats/:key
-- PARAMS: stats.name
CREATE OR REPLACE FUNCTION get_stats(text, OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.stats_view WHERE name = $1) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /statcount/:key
-- PARAMS: stats.name
CREATE OR REPLACE FUNCTION get_stat_value_count(text, OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT statvalue AS value, COUNT(*) AS count
		FROM peeps.userstats WHERE statkey=$1 GROUP BY statvalue ORDER BY statvalue) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /statcount
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION get_stat_name_count(OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT statkey AS name, COUNT(*) AS count
		FROM peeps.userstats GROUP BY statkey ORDER BY statkey) r;
END;
$$ LANGUAGE plpgsql;


-- POST /email
-- PARAMS: json of values to insert
-- KEYS: profile category message_id their_email their_name subject headers body
CREATE OR REPLACE FUNCTION import_email(json, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
	pid integer;
	rid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	-- insert as-is (easier to update once in database)
	-- created_by = 2  TODO: created_by=NULL for imports?
	INSERT INTO peeps.emails(created_by, profile, category, message_id, their_email,
		their_name, subject, headers, body) SELECT 2 AS created_by, profile, category,
		message_id, their_email, their_name, subject, headers, body
		FROM json_populate_record(null::peeps.emails, $1) RETURNING id INTO eid;
	-- if references.message_id found, update person_id, reference_id, category
	IF json_array_length($1 -> 'references') > 0 THEN
		UPDATE peeps.emails SET person_id=ref.person_id, reference_id=ref.id,
			category = COALESCE(peeps.people.categorize_as, peeps.emails.profile)
			FROM peeps.emails ref, peeps.people
			WHERE peeps.emails.id=eid AND ref.person_id=peeps.people.id
			AND ref.message_id IN
				(SELECT * FROM json_array_elements_text($1 -> 'references'))
			RETURNING emails.person_id, ref.id INTO pid, rid;
		IF rid IS NOT NULL THEN
			UPDATE peeps.emails SET answer_id=eid WHERE id=rid;
		END IF;
	END IF;
	-- if their_email is found, update person_id, category
	IF pid IS NULL THEN
		UPDATE peeps.emails e SET person_id=p.id,
			category=COALESCE(p.categorize_as, e.profile)
			FROM peeps.people p WHERE e.id=eid
			AND (p.email=e.their_email OR p.company=e.their_email)
			RETURNING e.person_id INTO pid;
	END IF;
	-- if still not found, set category to fix-client (TODO: make this unnecessary)
	IF pid IS NULL THEN
		UPDATE peeps.emails SET category='fix-client' WHERE id=eid
			RETURNING person_id INTO pid;
	END IF;
	-- insert attachments
	IF json_array_length($1 -> 'attachments') > 0 THEN
		INSERT INTO email_attachments(email_id, mime_type, filename, bytes)
			SELECT eid AS email_id, mime_type, filename, bytes FROM
			json_populate_recordset(null::peeps.email_attachments, $1 -> 'attachments');
	END IF;
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.email_view WHERE id=eid) r;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- Update mailing list settings for this person (whether new or existing)
-- POST /list
-- PARAMS name, email, listype ($3 should be: 'all', 'some', 'none', or 'dead')
CREATE OR REPLACE FUNCTION list_update(text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
	clean3 text;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	clean3 := regexp_replace($3, '[^a-z]', '', 'g');
	SELECT id INTO pid FROM peeps.person_create($1, $2);
	INSERT INTO peeps.userstats(person_id, statkey, statvalue)
		VALUES (pid, 'listype', clean3);
	UPDATE peeps.people SET listype=clean3 WHERE id=pid;
	mime := 'application/json';
	js := json_build_object('list', clean3);

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;



