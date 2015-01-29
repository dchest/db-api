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

-- API TODO:
-- get '/search/:q'
-- post '/authors'
-- post '/contributors'
-- post '/thoughts'

-- NOTE: all queries only show where thoughts.approved IS TRUE

-- get '/languages'
-- PARAMS: -none-
CREATE FUNCTION languages(OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	js := '["en","es","fr","de","it","pt","ja","zh","ar","ru"]';
END;
$$ LANGUAGE plpgsql;


-- get '/categories'
-- PARAMS: -none-
CREATE FUNCTION all_categories(OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT id, en, es, fr, de, it, pt, ja, zh, ar, ru,
		(SELECT COUNT(thoughts.id) FROM categories_thoughts, thoughts
			WHERE category_id=categories.id
			AND thoughts.id=categories_thoughts.thought_id AND thoughts.approved IS TRUE)
		AS howmany FROM categories ORDER BY id) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/categories/([0-9]+)$}
-- PARAMS: category id
CREATE FUNCTION category(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM categories WHERE id=$1) r;
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
CREATE FUNCTION top_authors(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM authors_view LIMIT $1) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/authors/([0-9]+)$}
-- PARAMS: author id
CREATE FUNCTION get_author(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM author_view WHERE id=$1) r;
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
CREATE FUNCTION top_contributors(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM contributors_view LIMIT $1) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/contributors/([0-9]+)$}
-- PARAMS: contributor id
CREATE FUNCTION get_contributor(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM contributor_view WHERE id=$1) r;
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
CREATE FUNCTION random_thought(OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM thought_view WHERE id =
		(SELECT id FROM thoughts WHERE as_rand IS TRUE ORDER BY RANDOM() LIMIT 1)) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/thoughts/([0-9]+)$}
-- PARAMS: thought id
CREATE FUNCTION get_thought(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM thought_view WHERE id = $1) r;
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
CREATE FUNCTION new_thoughts(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM thought_view LIMIT $1) r;
END;
$$ LANGUAGE plpgsql;

