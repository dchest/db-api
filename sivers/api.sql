-- POST %r{^/comments/([0-9]+)$}
-- PARAMS: comment id
CREATE FUNCTION get_comment(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM sivers.comments WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
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

