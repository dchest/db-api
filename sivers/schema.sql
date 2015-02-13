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

CREATE FUNCTION clean_comments_fields() RETURNS TRIGGER AS $$
BEGIN
	NEW.uri = regexp_replace(lower(NEW.uri), '[^a-z0-9-]', '', 'g');
	NEW.name = btrim(regexp_replace(NEW.name, '[\r\n\t]', ' ', 'g'));
	NEW.email = btrim(lower(NEW.email));
	NEW.html = replace(public.escape_html(public.strip_tags(btrim(NEW.html))),
			':-)',
			'<img src="/images/icon_smile.gif" width="15" height="15" alt="smile">');
	IF TG_OP = 'INSERT' AND NEW.person_id IS NULL THEN
		SELECT id INTO NEW.person_id FROM peeps.person_create(NEW.name, NEW.email);
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_comments_fields BEFORE INSERT OR UPDATE OF uri, name, email ON sivers.comments FOR EACH ROW EXECUTE PROCEDURE clean_comments_fields();

-- POST %r{^/comments/([0-9]+)$}
-- PARAMS: comment id
CREATE FUNCTION get_comment(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM sivers.comments WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST %r{^/comments/([0-9]+)$}
-- PARAMS: uri, name, email, html
CREATE FUNCTION add_comment(text, text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	new_id integer;
BEGIN
	INSERT INTO comments (uri, name, email, html)
		VALUES ($1, $2, $3, $4) RETURNING id INTO new_id;
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM
		(SELECT * FROM sivers.comments WHERE id=new_id) r;
END;
$$ LANGUAGE plpgsql;


