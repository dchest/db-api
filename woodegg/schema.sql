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
	duration varchar(7), -- h:mm:ss
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
-- NOTE: Assumes all answers and essays are complete and usable.
-- If, some day, new answers and essays are created, update queries
-- to add "where payable is true"

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
			AND books_researchers.researcher_id=researchers.id
			ORDER BY researchers.id) r),
	(SELECT json_agg(w) AS writers FROM
		(SELECT writers.id, peeps.people.name,
			CONCAT('/images/200/writers-', writers.id, '.jpg') AS image
			FROM writers, books_writers, peeps.people
			WHERE writers.person_id=peeps.people.id
			AND books_writers.book_id=books.id 
			AND books_writers.writer_id=writers.id
			ORDER BY writers.id) w),
	(SELECT json_agg(e) AS editors FROM
		(SELECT editors.id, peeps.people.name,
			CONCAT('/images/200/editors-', editors.id, '.jpg') AS image
			FROM editors, books_editors, peeps.people
			WHERE editors.person_id=peeps.people.id
			AND books_editors.book_id=books.id 
			AND books_editors.editor_id=editors.id
			ORDER BY editors.id) e)
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
			FROM answers WHERE question_id=questions.id ORDER BY answers.id) a),
	(SELECT json_agg(ess) AS essays FROM
		(SELECT id, date(started_at) AS date, edited AS essay,
		(SELECT row_to_json(w) AS writer FROM
			(SELECT writers.id, peeps.people.name,
				CONCAT('/images/200/writers-', writers.id, '.jpg') AS image
				FROM writers, peeps.people WHERE writers.id=essays.writer_id
				AND writers.person_id=peeps.people.id ORDER BY writers.id) w),
		(SELECT row_to_json(e) AS editor FROM
			(SELECT editors.id, peeps.people.name,
				CONCAT('/images/200/editors-', editors.id, '.jpg') AS image
				FROM editors, peeps.people WHERE editors.id=essays.editor_id
				AND editors.person_id=peeps.people.id ORDER BY editors.id) e)
			FROM essays WHERE question_id=questions.id ORDER BY essays.id) ess)
	FROM questions;

-- for country_view see API function get_country

DROP VIEW IF EXISTS templates_view CASCADE;
CREATE VIEW templates_view AS
	SELECT id, topic, (SELECT json_agg(sx) AS subtopics FROM
		(SELECT id, subtopic, (SELECT json_agg(tq) AS questions FROM
				(SELECT id, question FROM template_questions
					WHERE subtopic_id=st.id ORDER BY id) tq)
			FROM subtopics st WHERE st.topic_id=topics.id ORDER BY st.id) sx)
	FROM topics ORDER BY id;

DROP VIEW IF EXISTS template_view CASCADE;
CREATE VIEW template_view AS
	SELECT id, question, (SELECT json_agg(x) AS countries FROM
		(SELECT id, country, question,
			(SELECT json_agg(y) AS answers FROM
				(SELECT id, date(started_at) AS date, answer, sources,
					(SELECT row_to_json(r) AS researcher FROM
						(SELECT researchers.id, peeps.people.name,
						CONCAT('/images/200/researchers-', researchers.id, '.jpg') AS image
						FROM researchers, peeps.people WHERE researchers.id=a.researcher_id
						AND researchers.person_id=peeps.people.id) r)
				FROM answers a WHERE a.question_id=questions.id ORDER BY id) y),
			(SELECT json_agg(z) AS essays FROM
				(SELECT id, date(started_at) AS date, edited AS essay,
					(SELECT row_to_json(w) AS writer FROM
						(SELECT writers.id, peeps.people.name,
							CONCAT('/images/200/writers-', writers.id, '.jpg') AS image
							FROM writers, peeps.people WHERE writers.id=e.writer_id
							AND writers.person_id=peeps.people.id) w),
					(SELECT row_to_json(ed) AS editor FROM
						(SELECT editors.id, peeps.people.name,
							CONCAT('/images/200/editors-', editors.id, '.jpg') AS image
							FROM editors, peeps.people WHERE editors.id=e.editor_id
							AND editors.person_id=peeps.people.id) ed)
				FROM essays e WHERE e.question_id=questions.id ORDER BY id) z)
		FROM questions WHERE template_question_id=template_questions.id
		ORDER BY country) x)
	FROM template_questions;  -- WHERE id=1

DROP VIEW IF EXISTS uploads_view CASCADE;
CREATE VIEW uploads_view AS
	SELECT id, country, created_at AS date, our_filename AS filename, notes
		FROM uploads ORDER BY id;  -- WHERE country='KR'

DROP VIEW IF EXISTS upload_view CASCADE;
CREATE VIEW upload_view AS
	SELECT id, country, created_at AS date, our_filename AS filename, notes,
		mime_type, bytes, transcription FROM uploads;  -- WHERE id=1

----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

-- POST /login
-- PARAMS: email, password
CREATE OR REPLACE FUNCTION login(text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
	cook text;
BEGIN
	SELECT p.id INTO pid
		FROM peeps.person_email_pass($1, $2) p, woodegg.customers c
		WHERE p.id=c.person_id;
	IF pid IS NOT NULL THEN
		SELECT cookie INTO cook FROM peeps.login_person_domain(pid, 'woodegg.com');
	END IF;
	IF cook IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 ELSE
		mime := 'application/json';
		js := json_build_object('cookie', cook);
	END IF;
EXCEPTION WHEN OTHERS THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);

END;
$$ LANGUAGE plpgsql;


-- GET /customer/{cookie}
-- PARAMS: cookie string
CREATE OR REPLACE FUNCTION get_customer(text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT c.id, name
		FROM peeps.get_person_from_cookie($1) p, woodegg.customers c
		WHERE p.id=c.person_id) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /reset/{reset_string}
-- PARAMS: 8-char string from https://woodegg.com/reset/:str
CREATE OR REPLACE FUNCTION get_customer_reset(text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
	cid integer;
BEGIN
	SELECT p.id, c.id INTO pid, cid
		FROM peeps.people p, woodegg.customers c
		WHERE p.newpass=$1
		AND p.id=c.person_id;
	IF pid IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 ELSE
		mime := 'application/json';
		-- this is just acknowledgement that it's approved to show reset form:
		js := json_build_object('person_id', pid, 'customer_id', cid, 'reset', $1);
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /reset/{reset_string}
-- PARAMS: reset string, new password
CREATE OR REPLACE FUNCTION set_customer_password(text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
	cid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT p.id, c.id INTO pid, cid
		FROM peeps.people p, woodegg.customers c
		WHERE p.newpass=$1
		AND p.id=c.person_id;
	IF pid IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 ELSE
		PERFORM peeps.set_password(pid, $2);
		mime := 'application/json';
		-- this is just acknowledgement that it's done:
		js := row_to_json(r) FROM (SELECT id, name, email, address
			FROM peeps.people WHERE id=pid) r;
	END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- POST /register
-- PARAMS: name, email, password, proof
CREATE OR REPLACE FUNCTION register(text, text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT id INTO pid FROM peeps.person_create_pass($1, $2, $3);
	INSERT INTO peeps.userstats(person_id, statkey, statvalue)
		VALUES (pid, 'proof-we14asia', $4);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT id, name, email, address
		FROM peeps.people WHERE id=pid) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


-- POST /forgot
-- PARAMS: email
CREATE OR REPLACE FUNCTION forgot(text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
	pnp text;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT p.id, p.newpass INTO pid, pnp FROM peeps.people p, woodegg.customers c
		WHERE p.id=c.person_id AND p.email = lower(regexp_replace($1, '\s', '', 'g'));
	IF pid IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 ELSE
		IF pnp IS NULL THEN
			UPDATE peeps.people SET
			newpass = public.unique_for_table_field(8, 'peeps.people', 'newpass')
			WHERE id = pid RETURNING newpass INTO pnp;
		END IF;
		-- PARAMS: emailer_id, person_id, profile, category, subject, body, reference_id
		PERFORM peeps.outgoing_email(1, pid, 'we@woodegg', 'we@woodegg',
			'your Wood Egg password reset link',
			'Click to reset your password:\n\nhttps://woodegg.com/reset/' || pnp,
			NULL);
		mime := 'application/json';
		js := row_to_json(r) FROM (SELECT id, name, email, address
			FROM peeps.people WHERE id=pid) r;
	END IF;

EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);

END;
$$ LANGUAGE plpgsql;


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


-- GET /country/KR
-- PARAMS: country code
CREATE OR REPLACE FUNCTION get_country(text, OUT mime text, OUT js json) AS $$
DECLARE
	rowcount integer;
BEGIN
	-- stop here if country code invalid (using books because least # of rows)
	SELECT COUNT(*) INTO rowcount FROM books WHERE country=$1;
	IF rowcount = 0 THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 RETURN; END IF;
	mime := 'application/json';
	-- JSON here instead of VIEW because needs $1 for q.country join inside query
	js := json_agg(cv) FROM (SELECT id, topic, (SELECT json_agg(st) AS subtopics FROM
		(SELECT id, subtopic, (SELECT json_agg(qs) AS questions FROM
			(SELECT q.id, q.question FROM questions q, template_questions tq
				WHERE q.template_question_id=tq.id AND subtopic_id=sub.id
				AND q.country=$1 ORDER BY q.id) qs)
			FROM subtopics sub WHERE topics.id=topic_id ORDER BY id) st)
		FROM topics ORDER BY id) cv;
END;
$$ LANGUAGE plpgsql;


-- GET /questions/1234
-- PARAMS: question id
CREATE OR REPLACE FUNCTION get_question(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM question_view WHERE id=$1) r;
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
-- PARAMS: book id
CREATE OR REPLACE FUNCTION get_book(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM book_view WHERE id=$1) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /templates
CREATE OR REPLACE FUNCTION get_templates(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM templates_view) r;
END;
$$ LANGUAGE plpgsql;


-- GET /templates/123
-- PARAMS: template id
CREATE OR REPLACE FUNCTION get_template(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM template_view WHERE id=$1) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /topics/5
-- PARAMS: topic id
CREATE OR REPLACE FUNCTION get_topic(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM templates_view WHERE id=$1) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /uploads/KR
-- PARAMS: country code
CREATE OR REPLACE FUNCTION get_uploads(text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM uploads_view WHERE country=$1) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /uploads/33
-- PARAMS: upload id#
CREATE OR REPLACE FUNCTION get_upload(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM upload_view WHERE id=$1) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
END;
$$ LANGUAGE plpgsql;




