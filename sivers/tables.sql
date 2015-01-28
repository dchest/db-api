SET client_min_messages TO ERROR;
DROP SCHEMA IF EXISTS sivers CASCADE;
BEGIN;

CREATE SCHEMA sivers;
SET search_path = sivers;

CREATE TABLE comments (
	id serial primary key,
	uri varchar(32) not null CONSTRAINT valid_uri CHECK (uri ~ '\A[a-z0-9-]+\Z'),
	person_id integer not null REFERENCES peeps.people(id) ON DELETE CASCADE,
	created_at date not null default CURRENT_DATE,
	name text CHECK (length(name) > 0),
	email text CONSTRAINT valid_email CHECK (email ~ '\A\S+@\S+\.\S+\Z'),
	html text not null CHECK (length(html) > 0)
);
CREATE INDEX comuri ON comments(uri);
CREATE INDEX compers ON comments(person_id);

COMMIT;

