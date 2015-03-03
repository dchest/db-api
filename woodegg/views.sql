----------------------------------------
--------------- VIEWS FOR JSON RESPONSES:
----------------------------------------

DROP VIEW IF EXISTS researcher_view CASCADE;
CREATE VIEW researcher_view AS
	SELECT researchers.id, peeps.people.name, researchers.bio,
		CONCAT('/images/200/researchers-', researchers.id, '.jpg') AS image
		FROM woodegg.researchers, peeps.people
		WHERE researchers.person_id=peeps.people.id;

DROP VIEW IF EXISTS writer_view CASCADE;
CREATE VIEW writer_view AS
	SELECT writers.id, peeps.people.name, writers.bio,
		CONCAT('/images/200/writers-', writers.id, '.jpg') AS image
		FROM woodegg.writers, peeps.people
		WHERE writers.person_id=peeps.people.id;

DROP VIEW IF EXISTS editor_view CASCADE;
CREATE VIEW editor_view AS
	SELECT editors.id, peeps.people.name, editors.bio,
		CONCAT('/images/200/editors-', editors.id, '.jpg') AS image
		FROM woodegg.editors, peeps.people
		WHERE editors.person_id=peeps.people.id;

DROP VIEW IF EXISTS answer_view CASCADE;
CREATE VIEW answer_view AS
	SELECT id, date(started_at) AS date, answer, sources,
	(SELECT row_to_json(r) AS researcher FROM
		(SELECT researchers.id, peeps.people.name,
			CONCAT('/images/200/researchers-', researchers.id, '.jpg') AS image
			FROM researchers, peeps.people WHERE researchers.id=answers.researcher_id
			AND researchers.person_id=peeps.people.id) r)
	FROM answers;

DROP VIEW IF EXISTS essay_view CASCADE;
CREATE VIEW essay_view AS
	SELECT id, date(started_at) AS date, edited AS essay,
	(SELECT row_to_json(w) AS writer FROM
		(SELECT writers.id, peeps.people.name,
			CONCAT('/images/200/writers-', writers.id, '.jpg') AS image
			FROM writers, peeps.people WHERE writers.id=essays.writer_id
			AND writers.person_id=peeps.people.id) w),
	(SELECT row_to_json(e) AS editor FROM
		(SELECT editors.id, peeps.people.name,
			CONCAT('/images/200/editors-', editors.id, '.jpg') AS image
			FROM editors, peeps.people WHERE editors.id=essays.editor_id
			AND editors.person_id=peeps.people.id) e)
	FROM essays;

DROP VIEW IF EXISTS book_view CASCADE;
CREATE VIEW book_view AS
	SELECT id, country, title, isbn, asin, leanpub, apple, salescopy, credits,
	(SELECT json_agg(r) AS researchers FROM
		(SELECT researchers.id, peeps.people.name,
			CONCAT('/images/200/researchers-', researchers.id, '.jpg') AS image
			FROM researchers, books_researchers, peeps.people
			WHERE researchers.person_id=peeps.people.id
			AND books_researchers.book_id=books.id 
			AND books_researchers.researcher_id=researchers.id) r),
	(SELECT json_agg(w) AS writers FROM
		(SELECT writers.id, peeps.people.name,
			CONCAT('/images/200/writers-', writers.id, '.jpg') AS image
			FROM writers, books_writers, peeps.people
			WHERE writers.person_id=peeps.people.id
			AND books_writers.book_id=books.id 
			AND books_writers.writer_id=writers.id) w),
	(SELECT json_agg(e) AS editors FROM
		(SELECT editors.id, peeps.people.name,
			CONCAT('/images/200/editors-', editors.id, '.jpg') AS image
			FROM editors, books_editors, peeps.people
			WHERE editors.person_id=peeps.people.id
			AND books_editors.book_id=books.id 
			AND books_editors.editor_id=editors.id) e)
	FROM books;

DROP VIEW IF EXISTS question_view CASCADE;
CREATE VIEW question_view AS
	SELECT id, country, template_question_id AS template_id, question,
	(SELECT json_agg(a) AS answers FROM
		(SELECT id, date(started_at) AS date, answer, sources,
		(SELECT row_to_json(r) AS researcher FROM
			(SELECT researchers.id, peeps.people.name,
				CONCAT('/images/200/researchers-', researchers.id, '.jpg') AS image
				FROM researchers, peeps.people WHERE researchers.id=answers.researcher_id
				AND researchers.person_id=peeps.people.id) r)
			FROM answers WHERE question_id=questions.id) a),
	(SELECT json_agg(ee) AS essays FROM
		(SELECT id, date(started_at) AS date, edited AS essay,
		(SELECT row_to_json(w) AS writer FROM
			(SELECT writers.id, peeps.people.name,
				CONCAT('/images/200/writers-', writers.id, '.jpg') AS image
				FROM writers, peeps.people WHERE writers.id=essays.writer_id
				AND writers.person_id=peeps.people.id) w),
		(SELECT row_to_json(e) AS editor FROM
			(SELECT editors.id, peeps.people.name,
				CONCAT('/images/200/editors-', editors.id, '.jpg') AS image
				FROM editors, peeps.people WHERE editors.id=essays.editor_id
				AND editors.person_id=peeps.people.id) e)
			FROM essays WHERE question_id=questions.id) ee)
	FROM questions;

DROP VIEW IF EXISTS country_view CASCADE;
-- {topics[{name subtopics[{name questions[{id question}]}]}] tidbits}
--CREATE VIEW country_view AS

DROP VIEW IF EXISTS templates_view CASCADE;
-- {topics[{id name subtopics[{name templates[{id template}]]]}
--CREATE VIEW templates_view AS

DROP VIEW IF EXISTS template_view CASCADE;
-- {topic subtopic template countries{code question answers[], essays[]}}
--CREATE VIEW template_view AS

DROP VIEW IF EXISTS topic_view CASCADE;
-- {subtopics[{name , templates {id }]}
--CREATE VIEW topic_view AS

DROP VIEW IF EXISTS subtopic_view CASCADE;
--CREATE VIEW subtopic_view AS

DROP VIEW IF EXISTS uploads_view CASCADE;
--CREATE VIEW uploads_view AS

DROP VIEW IF EXISTS upload_view CASCADE;
--CREATE VIEW upload_view AS

