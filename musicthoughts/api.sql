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
	SELECT json_agg(r) INTO js FROM (SELECT id, en, es, fr, de, it, pt, ja, zh, ar, ru,
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
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM categories WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- get '/authors'
-- get '/authors/top'
-- PARAMS: top limit  (NULL for all)
CREATE FUNCTION top_authors(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM authors_view LIMIT $1) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/authors/([0-9]+)$}
-- PARAMS: author id
CREATE FUNCTION get_author(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM author_view WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- get '/contributors'
-- get '/contributors/top'
-- PARAMS: top limit  (NULL for all)
CREATE FUNCTION top_contributors(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM contributors_view LIMIT $1) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/contributors/([0-9]+)$}
-- PARAMS: contributor id
CREATE FUNCTION get_contributor(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM contributor_view WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- get '/thoughts/random'
-- PARAMS: -none-
CREATE FUNCTION random_thought(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM thought_view WHERE id =
		(SELECT id FROM thoughts WHERE as_rand IS TRUE ORDER BY RANDOM() LIMIT 1)) r;
END;
$$ LANGUAGE plpgsql;


-- get %r{^/thoughts/([0-9]+)$}
-- PARAMS: thought id
CREATE FUNCTION get_thought(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM thought_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- get '/thoughts'
-- get '/thoughts/new'
-- PARAMS: newest limit (NULL for all)
CREATE FUNCTION new_thoughts(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM thought_view LIMIT $1) r;
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
m4_ERRVARS
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
m4_ERRCATCH
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
CREATE FUNCTION add_thought(char(2), text, text, text, text, text, text, text, integer[], OUT mime text, OUT js text) AS $$
DECLARE
	pers_id integer;
	cont_id integer;
	auth_id integer;
	newt_id integer;
	cat_id integer;
m4_ERRVARS
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
	FOREACH cat_id IN ARRAY $9 LOOP
		INSERT INTO categories_thoughts VALUES (newt_id, cat_id);
	END LOOP;
	mime := 'application/json';
	js := json_build_object(
		'thought', newt_id,
		'contributor', cont_id,
		'author', auth_id);
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


