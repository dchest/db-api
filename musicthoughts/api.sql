-- API TODO:
-- post '/authors'
-- post '/contributors'
-- post '/thoughts'

-- NOTE: all queries only show where thoughts.approved IS TRUE

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


