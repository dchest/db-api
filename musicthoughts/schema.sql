SET client_min_messages TO ERROR;
SET client_encoding = 'UTF8';
DROP SCHEMA IF EXISTS musicthoughts CASCADE;
BEGIN;

CREATE SCHEMA musicthoughts;
SET search_path = musicthoughts;

-- composing, performing, listening, etc
CREATE TABLE categories (
	id serial primary key,
	en text,
	es text,
	fr text,
	de text,
	it text,
	pt text,
	ja text,
	zh text,
	ar text,
	ru text
);

-- users who submit a thought
CREATE TABLE contributors (
	id serial primary key,
	person_id integer NOT NULL UNIQUE REFERENCES peeps.people(id),
	url varchar(255),  -- TODO: use peeps.people.urls.main
	place varchar(255)
);

-- famous people who said the thought
CREATE TABLE authors (
	id serial primary key,
	name varchar(127) UNIQUE,
	url varchar(255)
);

-- quotes
CREATE TABLE thoughts (
	id serial primary key,
	approved boolean default false,
	author_id integer not null REFERENCES authors(id) ON DELETE RESTRICT,
	contributor_id integer not null REFERENCES contributors(id) ON DELETE RESTRICT,
	created_at date not null default CURRENT_DATE,
	as_rand boolean not null default false, -- best-of to include in random selection
	source_url varchar(255),  -- where quote was found
	en text,
	es text,
	fr text,
	de text,
	it text,
	pt text,
	ja text,
	zh text,
	ar text,
	ru text
);

CREATE TABLE categories_thoughts (
	thought_id integer not null REFERENCES thoughts(id) ON DELETE CASCADE,
	category_id integer not null REFERENCES categories(id) ON DELETE RESTRICT,
	PRIMARY KEY (thought_id, category_id)
);
CREATE INDEX ctti ON categories_thoughts(thought_id);
CREATE INDEX ctci ON categories_thoughts(category_id);

COMMIT;

----------------------------------------
--------------- VIEWS FOR JSON RESPONSES:
----------------------------------------

CREATE VIEW category_view AS
	SELECT categories.*, (SELECT json_agg(t) FROM
		(SELECT id, en, es, fr, de, it, pt, ja, zh, ar, ru,
			(SELECT row_to_json(a) FROM
				(SELECT id, name FROM authors WHERE thoughts.author_id=authors.id) a) AS author
			FROM thoughts, categories_thoughts
			WHERE category_id=categories.id AND thought_id=thoughts.id AND approved IS TRUE
			ORDER BY id DESC) t) AS thoughts
		FROM categories;

CREATE VIEW authors_view AS
	SELECT id, name,
		(SELECT COUNT(*) FROM thoughts
			WHERE author_id=authors.id AND approved IS TRUE) AS howmany
		FROM authors WHERE id IN
			(SELECT author_id FROM thoughts WHERE approved IS TRUE)
		ORDER BY howmany DESC, name ASC;

CREATE VIEW contributors_view AS
	SELECT contributors.id, peeps.people.name,
		(SELECT COUNT(*) FROM thoughts
			WHERE contributor_id=contributors.id AND approved IS TRUE) AS howmany
		FROM contributors, peeps.people WHERE contributors.person_id=peeps.people.id
		AND contributors.id IN
			(SELECT contributor_id FROM thoughts WHERE approved IS TRUE)
		ORDER BY howmany DESC, name ASC;

CREATE VIEW author_view AS
	SELECT id, name, (SELECT json_agg(t) FROM
		(SELECT id, en, es, fr, de, it, pt, ja, zh, ar, ru FROM thoughts
			WHERE author_id=authors.id AND approved IS TRUE
			ORDER BY id DESC) t) AS thoughts
		FROM authors;

CREATE VIEW contributor_view AS
	SELECT contributors.id, peeps.people.name, (SELECT json_agg(t) FROM
		(SELECT id, en, es, fr, de, it, pt, ja, zh, ar, ru,
			(SELECT row_to_json(a) FROM
				(SELECT id, name FROM authors WHERE thoughts.author_id=authors.id) a) AS author
			FROM thoughts
			WHERE contributor_id=contributors.id AND approved IS TRUE
			ORDER BY id DESC) t) AS thoughts
		FROM contributors, peeps.people WHERE contributors.person_id=peeps.people.id;

CREATE VIEW thought_view AS
	SELECT id, source_url, en, es, fr, de, it, pt, ja, zh, ar, ru,
		(SELECT row_to_json(a) FROM
			(SELECT id, name FROM authors WHERE thoughts.author_id=authors.id) a) AS author,
		(SELECT row_to_json(c) FROM
			(SELECT contributors.id, peeps.people.name FROM contributors
				LEFT JOIN peeps.people ON contributors.person_id=peeps.people.id
				WHERE thoughts.contributor_id=contributors.id) c) AS contributor,
		(SELECT json_agg(ct) FROM
			(SELECT categories.* FROM categories, categories_thoughts
				WHERE categories_thoughts.category_id=categories.id
				AND categories_thoughts.thought_id=thoughts.id) ct) AS categories
		FROM thoughts WHERE approved IS TRUE ORDER BY id DESC;

-- NOTE: all queries only show where thoughts.approved IS TRUE
-- When building manager API, I will add unapproved thoughts function

-- get '/languages'
-- PARAMS: -none-
CREATE FUNCTION languages(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := '["en","es","fr","de","it","pt","ja","zh","ar","ru"]';
END;
$$ LANGUAGE plpgsql;


-- get '/categories'
-- PARAMS: -none-
CREATE FUNCTION all_categories(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT id, en, es, fr, de, it, pt, ja, zh, ar, ru,
		(SELECT COUNT(thoughts.id) FROM categories_thoughts, thoughts
			WHERE category_id=categories.id
			AND thoughts.id=categories_thoughts.thought_id AND thoughts.approved IS TRUE)
		AS howmany FROM categories ORDER BY id) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/categories/([0-9]+)$}
-- PARAMS: category id
CREATE FUNCTION category(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM category_view WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- get '/authors'
-- get '/authors/top'
-- PARAMS: top limit  (NULL for all)
CREATE FUNCTION top_authors(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM authors_view LIMIT $1) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/authors/([0-9]+)$}
-- PARAMS: author id
CREATE FUNCTION get_author(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM author_view WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- get '/contributors'
-- get '/contributors/top'
-- PARAMS: top limit  (NULL for all)
CREATE FUNCTION top_contributors(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM contributors_view LIMIT $1) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/contributors/([0-9]+)$}
-- PARAMS: contributor id
CREATE FUNCTION get_contributor(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM contributor_view WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- get '/thoughts/random'
-- PARAMS: -none-
CREATE FUNCTION random_thought(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM thought_view WHERE id =
		(SELECT id FROM thoughts WHERE as_rand IS TRUE ORDER BY RANDOM() LIMIT 1)) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/thoughts/([0-9]+)$}
-- PARAMS: thought id
CREATE FUNCTION get_thought(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM thought_view WHERE id = $1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- get '/thoughts'
-- get '/thoughts/new'
-- PARAMS: newest limit (NULL for all)
CREATE FUNCTION new_thoughts(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM thought_view LIMIT $1) r;
END;
$$ LANGUAGE plpgsql;

-- get '/search/:q'
-- PARAMS: search term
CREATE FUNCTION search(text, OUT mime text, OUT js json) AS $$
DECLARE
	q text;
	auth json;
	cont json;
	cats json;
	thts json;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	IF LENGTH(regexp_replace($1, '\s', '', 'g')) < 2 THEN
		RAISE 'search term too short';
	END IF;
	q := concat('%', btrim($1, E'\r\n\t '), '%');
	SELECT json_agg(r) INTO auth FROM
		(SELECT * FROM authors_view WHERE name ILIKE q) r;
	SELECT json_agg(r) INTO cont FROM
		(SELECT * FROM contributors_view WHERE name ILIKE q) r;
	SELECT json_agg(r) INTO cats FROM
		(SELECT * FROM categories WHERE
		CONCAT(en,'|',es,'|',fr,'|',de,'|',it,'|',pt,'|',ja,'|',zh,'|',ar,'|',ru)
			ILIKE q ORDER BY id) r;
	SELECT json_agg(r) INTO thts FROM
		(SELECT * FROM thought_view WHERE
		CONCAT(en,'|',es,'|',fr,'|',de,'|',it,'|',pt,'|',ja,'|',zh,'|',ar,'|',ru)
			ILIKE q ORDER BY id) r;
	mime := 'application/json';
	js := json_build_object(
		'authors', auth,
		'contributors', cont,
		'categories', cats,
		'thoughts', thts);

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


-- post '/thoughts'
-- PARAMS:
-- $1 = lang code
-- $2 = thought
-- $3 = contributor name
-- $4 = contributor email
-- $5 = contributor url
-- $6 = contributor place
-- $7 = author name
-- $8 = source url
-- $9 = array of category ids
-- Having ordered params is a drag, so is accepting then unnesting JSON with specific key names.
-- Returns simple hash of ids, since thought is unapproved and untranslated, no view yet.
CREATE FUNCTION add_thought(char(2), text, text, text, text, text, text, text, integer[], OUT mime text, OUT js json) AS $$
DECLARE
	pers_id integer;
	cont_id integer;
	auth_id integer;
	newt_id integer;
	cat_id integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT id INTO pers_id FROM peeps.person_create($3, $4);
	SELECT id INTO cont_id FROM contributors WHERE person_id = pers_id;
	IF cont_id IS NULL THEN
		INSERT INTO contributors (person_id, url, place) VALUES (pers_id, $5, $6)
			RETURNING id INTO cont_id;
	END IF;
	SELECT id INTO auth_id FROM authors WHERE name ILIKE btrim($7, E'\r\n\t ');
	IF auth_id IS NULL THEN
		INSERT INTO authors (name) VALUES ($7) RETURNING id INTO auth_id;
	END IF;
	EXECUTE format ('INSERT INTO thoughts (author_id, contributor_id, source_url, %I)'
		|| ' VALUES (%L, %L, %L, %L) RETURNING id', $1, auth_id, cont_id, $8, $2)
		INTO newt_id;
	IF $9 IS NOT NULL THEN
		FOREACH cat_id IN ARRAY $9 LOOP
			INSERT INTO categories_thoughts VALUES (newt_id, cat_id);
		END LOOP;
	END IF;
	mime := 'application/json';
	js := json_build_object(
		'thought', newt_id,
		'contributor', cont_id,
		'author', auth_id);

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


