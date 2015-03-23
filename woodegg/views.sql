----------------------------------------
--------------- VIEWS FOR JSON RESPONSES:
----------------------------------------
-- NOTE: Assumes all answers and essays are complete and usable.
-- If, some day, new answers and essays are created, update queries
-- to add "where payable is true"

DROP VIEW IF EXISTS researcher_view CASCADE;
CREATE VIEW researcher_view AS
	SELECT woodegg.researchers.id, peeps.people.name, woodegg.researchers.bio,
		CONCAT('/images/200/researchers-', woodegg.researchers.id, '.jpg') AS image
		FROM woodegg.researchers, peeps.people
		WHERE woodegg.researchers.person_id=peeps.people.id;

DROP VIEW IF EXISTS writer_view CASCADE;
CREATE VIEW writer_view AS
	SELECT woodegg.writers.id, peeps.people.name, woodegg.writers.bio,
		CONCAT('/images/200/writers-', woodegg.writers.id, '.jpg') AS image
		FROM woodegg.writers, peeps.people
		WHERE writers.person_id=peeps.people.id;

DROP VIEW IF EXISTS editor_view CASCADE;
CREATE VIEW editor_view AS
	SELECT woodegg.editors.id, peeps.people.name, woodegg.editors.bio,
		CONCAT('/images/200/editors-', woodegg.editors.id, '.jpg') AS image
		FROM woodegg.editors, peeps.people
		WHERE woodegg.editors.person_id=peeps.people.id;

DROP VIEW IF EXISTS answer_view CASCADE;
CREATE VIEW answer_view AS
	SELECT id, date(started_at) AS date, answer, sources,
	(SELECT row_to_json(r) AS researcher FROM
		(SELECT woodegg.researchers.id, peeps.people.name,
			CONCAT('/images/200/researchers-', woodegg.researchers.id, '.jpg') AS image
			FROM woodegg.researchers, peeps.people
			WHERE woodegg.researchers.id=woodegg.answers.researcher_id
			AND woodegg.researchers.person_id=peeps.people.id) r)
	FROM answers;

DROP VIEW IF EXISTS essay_view CASCADE;
CREATE VIEW essay_view AS
	SELECT id, date(started_at) AS date, edited AS essay,
	(SELECT row_to_json(w) AS writer FROM
		(SELECT woodegg.writers.id, peeps.people.name,
			CONCAT('/images/200/writers-', woodegg.writers.id, '.jpg') AS image
			FROM woodegg.writers, peeps.people
			WHERE woodegg.writers.id=woodegg.essays.writer_id
			AND woodegg.writers.person_id=peeps.people.id) w),
	(SELECT row_to_json(e) AS editor FROM
		(SELECT woodegg.editors.id, peeps.people.name,
			CONCAT('/images/200/editors-', editors.id, '.jpg') AS image
			FROM woodegg.editors, peeps.people
			WHERE woodegg.editors.id=woodegg.essays.editor_id
			AND woodegg.editors.person_id=peeps.people.id) e)
	FROM essays;

DROP VIEW IF EXISTS book_view CASCADE;
CREATE VIEW book_view AS
	SELECT id, country, title, isbn, asin, leanpub, apple, salescopy, credits,
	(SELECT json_agg(r) AS researchers FROM
		(SELECT woodegg.researchers.id, peeps.people.name,
			CONCAT('/images/200/researchers-', woodegg.researchers.id, '.jpg') AS image
			FROM woodegg.researchers, woodegg.books_researchers, peeps.people
			WHERE woodegg.researchers.person_id=peeps.people.id
			AND woodegg.books_researchers.book_id=woodegg.books.id 
			AND woodegg.books_researchers.researcher_id=woodegg.researchers.id
			ORDER BY woodegg.researchers.id) r),
	(SELECT json_agg(w) AS writers FROM
		(SELECT woodegg.writers.id, peeps.people.name,
			CONCAT('/images/200/writers-', woodegg.writers.id, '.jpg') AS image
			FROM woodegg.writers, woodegg.books_writers, peeps.people
			WHERE woodegg.writers.person_id=peeps.people.id
			AND woodegg.books_writers.book_id=woodegg.books.id 
			AND woodegg.books_writers.writer_id=woodegg.writers.id
			ORDER BY woodegg.writers.id) w),
	(SELECT json_agg(e) AS editors FROM
		(SELECT woodegg.editors.id, peeps.people.name,
			CONCAT('/images/200/editors-', woodegg.editors.id, '.jpg') AS image
			FROM woodegg.editors, woodegg.books_editors, peeps.people
			WHERE woodegg.editors.person_id=peeps.people.id
			AND woodegg.books_editors.book_id=woodegg.books.id 
			AND woodegg.books_editors.editor_id=woodegg.editors.id
			ORDER BY woodegg.editors.id) e)
	FROM books;

DROP VIEW IF EXISTS question_view CASCADE;
CREATE VIEW question_view AS
	SELECT id, country, template_question_id AS template_id, question,
	(SELECT json_agg(a) AS answers FROM
		(SELECT id, date(started_at) AS date, answer, sources,
		(SELECT row_to_json(r) AS researcher FROM
			(SELECT woodegg.researchers.id, peeps.people.name,
				CONCAT('/images/200/researchers-', woodegg.researchers.id, '.jpg') AS image
				FROM woodegg.researchers, peeps.people
				WHERE woodegg.researchers.id=woodegg.answers.researcher_id
				AND woodegg.researchers.person_id=peeps.people.id) r)
			FROM woodegg.answers WHERE question_id=questions.id ORDER BY woodegg.answers.id) a),
	(SELECT json_agg(ess) AS essays FROM
		(SELECT id, date(started_at) AS date, edited AS essay,
		(SELECT row_to_json(w) AS writer FROM
			(SELECT woodegg.writers.id, peeps.people.name,
				CONCAT('/images/200/writers-', woodegg.writers.id, '.jpg') AS image
				FROM woodegg.writers, peeps.people
				WHERE woodegg.writers.id=woodegg.essays.writer_id
				AND woodegg.writers.person_id=peeps.people.id ORDER BY woodegg.writers.id) w),
		(SELECT row_to_json(e) AS editor FROM
			(SELECT woodegg.editors.id, peeps.people.name,
				CONCAT('/images/200/editors-', woodegg.editors.id, '.jpg') AS image
				FROM woodegg.editors, peeps.people
				WHERE woodegg.editors.id=woodegg.essays.editor_id
				AND woodegg.editors.person_id=peeps.people.id ORDER BY woodegg.editors.id) e)
			FROM woodegg.essays WHERE question_id=questions.id ORDER BY woodegg.essays.id) ess)
	FROM questions;

-- for country_view see API function get_country

DROP VIEW IF EXISTS templates_view CASCADE;
CREATE VIEW templates_view AS
	SELECT id, topic, (SELECT json_agg(sx) AS subtopics FROM
		(SELECT id, subtopic, (SELECT json_agg(tq) AS questions FROM
				(SELECT id, question FROM woodegg.template_questions
					WHERE subtopic_id=st.id ORDER BY id) tq)
			FROM woodegg.subtopics st WHERE st.topic_id=woodegg.topics.id ORDER BY st.id) sx)
	FROM woodegg.topics ORDER BY id;

DROP VIEW IF EXISTS template_view CASCADE;
CREATE VIEW template_view AS
	SELECT id, question, (SELECT json_agg(x) AS countries FROM
		(SELECT id, country, question,
			(SELECT json_agg(y) AS answers FROM
				(SELECT id, date(started_at) AS date, answer, sources,
					(SELECT row_to_json(r) AS researcher FROM
						(SELECT woodegg.researchers.id, peeps.people.name,
						CONCAT('/images/200/researchers-', woodegg.researchers.id, '.jpg') AS image
						FROM woodegg.researchers, peeps.people
						WHERE woodegg.researchers.id=a.researcher_id
						AND woodegg.researchers.person_id=peeps.people.id) r)
				FROM woodegg.answers a WHERE a.question_id=woodegg.questions.id ORDER BY id) y),
			(SELECT json_agg(z) AS essays FROM
				(SELECT id, date(started_at) AS date, edited AS essay,
					(SELECT row_to_json(w) AS writer FROM
						(SELECT woodegg.writers.id, peeps.people.name,
							CONCAT('/images/200/writers-', woodegg.writers.id, '.jpg') AS image
							FROM woodegg.writers, peeps.people WHERE woodegg.writers.id=e.writer_id
							AND woodegg.writers.person_id=peeps.people.id) w),
					(SELECT row_to_json(ed) AS editor FROM
						(SELECT woodegg.editors.id, peeps.people.name,
							CONCAT('/images/200/editors-', woodegg.editors.id, '.jpg') AS image
							FROM woodegg.editors, peeps.people WHERE woodegg.editors.id=e.editor_id
							AND woodegg.editors.person_id=peeps.people.id) ed)
				FROM woodegg.essays e WHERE e.question_id=woodegg.questions.id ORDER BY id) z)
		FROM woodegg.questions WHERE template_question_id=template_questions.id
		ORDER BY country) x)
	FROM woodegg.template_questions;  -- WHERE id=1

DROP VIEW IF EXISTS uploads_view CASCADE;
CREATE VIEW uploads_view AS
	SELECT id, country, created_at AS date, our_filename AS filename, notes
		FROM woodegg.uploads ORDER BY id;  -- WHERE country='KR'

DROP VIEW IF EXISTS upload_view CASCADE;
CREATE VIEW upload_view AS
	SELECT id, country, created_at AS date, our_filename AS filename, notes,
		mime_type, bytes, transcription FROM woodegg.uploads;  -- WHERE id=1

