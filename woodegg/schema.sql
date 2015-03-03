SET client_min_messages TO ERROR;
DROP SCHEMA IF EXISTS woodegg CASCADE;
CREATE SCHEMA woodegg;

SET search_path = woodegg;
BEGIN;

CREATE TABLE researchers (
	id serial PRIMARY KEY,
	person_id integer not null UNIQUE REFERENCES peeps.people(id),
	bio text
);

CREATE TABLE writers (
	id serial PRIMARY KEY,
	person_id integer not null UNIQUE REFERENCES peeps.people(id),
	bio text
);

CREATE TABLE editors (
	id serial PRIMARY KEY,
	person_id integer not null UNIQUE REFERENCES peeps.people(id),
	bio text
);

CREATE TABLE customers (
	id serial PRIMARY KEY,
	person_id integer not null UNIQUE REFERENCES peeps.people(id)
);

CREATE TABLE topics (
	id serial PRIMARY KEY,
	topic varchar(32) not null CHECK (length(topic) > 0)
);

CREATE TABLE subtopics (
	id serial PRIMARY KEY,
	topic_id integer not null REFERENCES topics(id),
	subtopic varchar(64) not null CHECK (length(subtopic) > 0)
);

CREATE TABLE template_questions (
	id serial PRIMARY KEY,
	subtopic_id integer not null REFERENCES subtopics(id),
	question text
);
CREATE INDEX tqti ON template_questions(subtopic_id);

CREATE TABLE questions (
	id serial PRIMARY KEY,
	template_question_id integer not null REFERENCES template_questions(id),
	country char(2) not null REFERENCES peeps.countries(code),
	question text
);
CREATE INDEX qtqi ON questions(template_question_id);

CREATE TABLE answers (
	id serial PRIMARY KEY,
	question_id integer not null REFERENCES questions(id),
	researcher_id integer not null REFERENCES researchers(id),
	started_at timestamp(0) with time zone,
	finished_at timestamp(0) with time zone,
	answer text,
	sources text
);
CREATE INDEX anqi ON answers(question_id);
CREATE INDEX anri ON answers(researcher_id);

CREATE TABLE books (
	id serial PRIMARY KEY,
	country char(2) not null REFERENCES peeps.countries(code),
	code char(6) not null UNIQUE,
	title text,
	pages integer,
	isbn char(13),
	asin char(10),
	leanpub varchar(30),
	apple integer,
	salescopy text,
	credits text,
	available boolean
);

CREATE TABLE books_writers (
	book_id integer not null REFERENCES books(id),
	writer_id integer not null REFERENCES writers(id),
	PRIMARY KEY (book_id, writer_id)
);

CREATE TABLE books_researchers (
	book_id integer not null references books(id),
	researcher_id integer not null references researchers(id),
	PRIMARY KEY (book_id, researcher_id)
);

CREATE TABLE books_customers (
	book_id integer not null references books(id),
	customer_id integer not null references customers(id),
	PRIMARY KEY (book_id, customer_id)
);

CREATE TABLE books_editors (
	book_id integer not null REFERENCES books(id),
	editor_id integer not null REFERENCES editors(id),
	PRIMARY KEY (book_id, editor_id)
);

CREATE TABLE essays (
	id serial PRIMARY KEY,
	question_id integer not null REFERENCES questions(id),
	writer_id integer not null REFERENCES writers(id),
	book_id integer not null REFERENCES books(id),
	editor_id integer REFERENCES writers(id),
	started_at timestamp(0) with time zone,
	finished_at timestamp(0) with time zone,
	edited_at timestamp(0) with time zone,
	content text,
	edited text
);
CREATE INDEX esqi ON essays(question_id);
CREATE INDEX esbi ON essays(book_id);

CREATE TABLE tags (
	id serial PRIMARY KEY,
	name varchar(16) UNIQUE
);

CREATE TABLE tidbits (
	id serial PRIMARY KEY,
	created_at date,
	created_by varchar(16),
	headline varchar(127),
	url text,
	intro text,
	content text
);

CREATE TABLE tags_tidbits (
	tag_id integer not null REFERENCES tags(id) ON DELETE CASCADE,
	tidbit_id integer not null REFERENCES tidbits(id) ON DELETE CASCADE,
	PRIMARY KEY (tag_id, tidbit_id)
);

CREATE TABLE questions_tidbits (
	question_id integer not null REFERENCES questions(id) ON DELETE CASCADE,
	tidbit_id integer not null REFERENCES tidbits(id) ON DELETE CASCADE,
	PRIMARY KEY (question_id, tidbit_id)
);

CREATE TABLE uploads (
	id serial PRIMARY KEY,
	created_at date NOT NULL DEFAULT CURRENT_DATE,
	researcher_id integer not null REFERENCES researchers(id),
	country char(2) not null REFERENCES peeps.countries(code),
	their_filename text not null,
	our_filename text not null,
	mime_type varchar(32),
	bytes integer,
	uploaded char(1) NOT NULL DEFAULT 'n',
	status varchar(4) default 'new',
	notes text,
	transcription text
);

CREATE TABLE test_essays (
	id serial PRIMARY KEY,
	person_id integer not null REFERENCES peeps.people(id),
	country char(2) not null REFERENCES peeps.countries(code),
	question_id integer REFERENCES questions(id),
	started_at timestamp(0) with time zone,
	finished_at timestamp(0) with time zone,
	content text,
	notes text
);

COMMIT;

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

----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

-- GET /researchers/1
-- PARAMS: researcher_id
CREATE OR REPLACE FUNCTION get_researcher(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM researcher_view WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /writers/1
-- PARAMS: writer_id
CREATE OR REPLACE FUNCTION get_writer(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM writer_view WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /editors/1
-- PARAMS: editor_id
CREATE OR REPLACE FUNCTION get_editor(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM editor_view WHERE id=$1) r;
	IF js IS NULL THEN

	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

	END IF;
END;
$$ LANGUAGE plpgsql;

-- GET /books/23 
-- GET /country/KR
-- GET /questions/1234
-- GET /templates
-- GET /templates/123
-- GET /topics/5
-- GET /subtopics/55
-- GET /uploads/KR
-- GET /uploads/33


