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

CREATE VIEW author_view AS
	SELECT id, name, (SELECT json_agg(t) FROM
		(SELECT id, en, es, fr, de, it, pt, ja, zh, ar, ru FROM thoughts
			WHERE author_id=authors.id AND approved IS TRUE
			ORDER BY id DESC) t) AS thoughts
	FROM authors;

-- API TODO:
-- get %r{^/contributors/([0-9]+)$}
-- get '/thoughts/random'
-- get '/search/:q'
-- get '/categories'
-- get %r{^/categories/([0-9]+)/thoughts$}
-- get '/authors'
-- get %r{^/authors/([0-9]+)/thoughts$}
-- get '/contributors'
-- get '/contributors/top'
-- get %r{^/contributors/([0-9]+)/thoughts$}
-- get '/thoughts'
-- get '/thoughts/new'
-- get %r{^/thoughts/([0-9]+)$}
-- post '/authors'
-- post '/contributors'
-- post '/thoughts'

-- get '/languages'
-- PARAMS: -none-
CREATE FUNCTION languages(OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	js := '["en","es","fr","de","it","pt","ja","zh","ar","ru"]';
END;
$$ LANGUAGE plpgsql;


-- get %r{^/categories/([0-9]+)$}
-- PARAMS: category i
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


-- get '/authors/top'
-- PARAMS: -none-
CREATE FUNCTION top_authors(OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT id, name, (SELECT COUNT(*) FROM thoughts
		WHERE author_id=authors.id AND approved IS TRUE) AS howmany FROM authors
		ORDER BY howmany DESC, name LIMIT 20) r;
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


