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
m4_NOTFOUND
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
m4_ERRVARS
BEGIN
	new_uri := regexp_replace(lower($1), '[^a-z0-9-]', '', 'g');
	new_name := btrim(regexp_replace($2, '[\r\n\t]', ' ', 'g'));
	new_email := btrim(lower($3));
	new_html := replace(public.escape_html(public.strip_tags(btrim($4))),
		':-)',
		'<img src="/images/icon_smile.gif" width="15" height="15" alt="smile">');
	SELECT id INTO new_person_id FROM peeps.person_create(new_name, new_email);
	INSERT INTO comments (uri, name, email, html, person_id)
		VALUES (new_uri, new_name, new_email, new_html, new_person_id)
		RETURNING id INTO new_id;
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM sivers.comments WHERE id=new_id) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PUT %r{^/comments/([0-9]+)$}
-- PARAMS: comments.id, JSON of values to update
CREATE OR REPLACE FUNCTION update_comment(integer, json, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM public.jsonupdate('sivers.comments', $1, $2,
		public.cols2update('sivers', 'comments', ARRAY['id','created_at']));
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM sivers.comments WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
m4_ERRCATCH
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
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- DELETE %r{^/comments/([0-9]+)$}
-- PARAMS: comment_id
CREATE OR REPLACE FUNCTION delete_comment(integer, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM sivers.comments WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
	DELETE FROM sivers.comments WHERE id = $1;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE %r{^/comments/([0-9]+)/spam$}
-- PARAMS: comment_id
CREATE OR REPLACE FUNCTION spam_comment(integer, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
m4_ERRVARS
BEGIN
	SELECT person_id INTO pid FROM sivers.comments WHERE id = $1;
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM sivers.comments WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
	DELETE FROM sivers.comments WHERE person_id = pid;
	DELETE FROM peeps.people WHERE id = pid;
m4_ERRCATCH
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

