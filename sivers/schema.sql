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
	name text not null CHECK (length(name) > 0),
	email text CONSTRAINT valid_email CHECK (email ~ '\A\S+@\S+\.\S+\Z'),
	html text not null CHECK (length(html) > 0)
);
CREATE INDEX comuri ON comments(uri);
CREATE INDEX compers ON comments(person_id);

COMMIT;

CREATE FUNCTION clean_comments_fields() RETURNS TRIGGER AS $$
BEGIN
	NEW.uri = regexp_replace(lower(NEW.uri), '[^a-z0-9-]', '', 'g');
	NEW.name = trim(regexp_replace(NEW.name, '[\r\n\t]', ' ', 'g'));
	NEW.email = trim(lower(NEW.email));
	IF TG_OP = 'INSERT' AND NEW.person_id IS NULL THEN
		SELECT id INTO NEW.person_id FROM peeps.person_create(NEW.name, NEW.email);
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_comments_fields BEFORE INSERT OR UPDATE OF uri, name, email ON sivers.comments FOR EACH ROW EXECUTE PROCEDURE clean_comments_fields();


