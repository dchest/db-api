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

CREATE FUNCTION comments_changed() RETURNS TRIGGER AS $$
DECLARE
	u text;
BEGIN
	IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
		u := NEW.uri;
	ELSE
		u := OLD.uri;
	END IF;
	PERFORM pg_notify('comments_changed', u);
	RETURN OLD;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER comments_changed AFTER INSERT OR UPDATE OR DELETE ON comments FOR EACH ROW EXECUTE PROCEDURE comments_changed();

----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

-- GET %r{^/comments/([0-9]+)$}
-- PARAMS: comment id
CREATE OR REPLACE FUNCTION get_comment(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT *, (SELECT row_to_json(p) AS person FROM
			(SELECT * FROM peeps.person_view WHERE id=sivers.comments.person_id) p)
		FROM sivers.comments WHERE id=$1) r;
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
CREATE OR REPLACE FUNCTION add_comment(text, text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	new_uri text;
	new_name text;
	new_email text;
	new_html text;
	new_person_id integer;
	new_id integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	new_uri := regexp_replace(lower($1), '[^a-z0-9-]', '', 'g');
	new_name := btrim(regexp_replace($2, '[\r\n\t]', ' ', 'g'));
	new_email := btrim(lower($3));
	new_html := replace(peeps.escape_html(peeps.strip_tags(btrim($4))),
		':-)',
		'<img src="/images/icon_smile.gif" width="15" height="15" alt="smile">');
	SELECT id INTO new_person_id FROM peeps.person_create(new_name, new_email);
	INSERT INTO sivers.comments (uri, name, email, html, person_id)
		VALUES (new_uri, new_name, new_email, new_html, new_person_id)
		RETURNING id INTO new_id;
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM sivers.comments WHERE id=new_id) r;

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


-- PUT %r{^/comments/([0-9]+)$}
-- PARAMS: comments.id, JSON of values to update
CREATE OR REPLACE FUNCTION update_comment(integer, json, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	PERFORM peeps.jsonupdate('sivers.comments', $1, $2,
		peeps.cols2update('sivers', 'comments', ARRAY['id','created_at']));
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM sivers.comments WHERE id=$1) r;
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


-- POST %r{^/comments/([0-9]+)/reply$}
-- PARAMS: comment_id, my reply
CREATE OR REPLACE FUNCTION reply_to_comment(integer, text, OUT mime text, OUT js json) AS $$
BEGIN
	UPDATE sivers.comments SET html = CONCAT(html, '<br><span class="response">',
		replace($2, ':-)',
		'<img src="/images/icon_smile.gif" width="15" height="15" alt="smile">'),
		' -- Derek</span>') WHERE id = $1;
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM sivers.comments WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- DELETE %r{^/comments/([0-9]+)$}
-- PARAMS: comment_id
CREATE OR REPLACE FUNCTION delete_comment(integer, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM sivers.comments WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
	DELETE FROM sivers.comments WHERE id = $1;

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


-- DELETE %r{^/comments/([0-9]+)/spam$}
-- PARAMS: comment_id
CREATE OR REPLACE FUNCTION spam_comment(integer, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT person_id INTO pid FROM sivers.comments WHERE id = $1;
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM sivers.comments WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
	DELETE FROM sivers.comments WHERE person_id = pid;
	DELETE FROM peeps.people WHERE id = pid;

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


-- GET '/comments/new'
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION new_comments(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM
		(SELECT * FROM comments ORDER BY id DESC LIMIT 100) r;
END;
$$ LANGUAGE plpgsql;


