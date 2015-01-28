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
m4_NOTFOUND
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
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


