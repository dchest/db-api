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

