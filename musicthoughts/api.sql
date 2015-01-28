-- API TODO:
-- get %r{^/categories/([0-9]+)$}
-- get '/authors/top'
-- get %r{^/authors/([0-9]+)$}
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


