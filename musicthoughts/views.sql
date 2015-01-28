----------------------------------------
--------------- VIEWS FOR JSON RESPONSES:
----------------------------------------

CREATE VIEW author_view AS
	SELECT id, name, (SELECT json_agg(t) FROM
		(SELECT id, en, es, fr, de, it, pt, ja, zh, ar, ru FROM thoughts
			WHERE author_id=authors.id AND approved IS TRUE
			ORDER BY id DESC) t) AS thoughts
	FROM authors;

