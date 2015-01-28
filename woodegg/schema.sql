SET client_min_messages TO ERROR;
SET client_encoding = 'UTF8';
DROP SCHEMA IF EXISTS woodegg CASCADE;
BEGIN;

CREATE SCHEMA woodegg;
SET search_path = woodegg;

CREATE TABLE researchers (
	id serial PRIMARY KEY,
	person_id integer not null UNIQUE REFERENCES peeps.people(id),
	active boolean not null default TRUE,
	bio text
);

CREATE TABLE writers (
	id serial PRIMARY KEY,
	person_id integer not null UNIQUE REFERENCES peeps.people(id),
	active boolean not null default TRUE,
	bio text
);

CREATE TABLE customers (
	id serial PRIMARY KEY,
	person_id integer not null UNIQUE REFERENCES peeps.people(id)
);

CREATE TABLE editors (
	id serial PRIMARY KEY,
	person_id integer not null UNIQUE REFERENCES peeps.people(id),
	bio text
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
	country char(2) not null, -- TODO: REFERENCES peeps.countries.code
	question text
);
CREATE INDEX qtqi ON questions(template_question_id);

CREATE TABLE answers (
	id serial PRIMARY KEY,
	question_id integer not null REFERENCES questions(id),
	researcher_id integer not null REFERENCES researchers(id),
	started_at timestamp(0) with time zone,
	finished_at timestamp(0) with time zone,
	payable boolean,
	answer text,
	sources text
);
CREATE INDEX anqi ON answers(question_id);
CREATE INDEX anri ON answers(researcher_id);
CREATE INDEX ansa ON answers(started_at);
CREATE INDEX anfa ON answers(finished_at);
CREATE INDEX anpy ON answers(payable);

CREATE TABLE books (
	id serial PRIMARY KEY,
	country char(2) not null, -- TODO: REFERENCES peeps.countries.code
	code char(6) not null UNIQUE,
	title text,
	pages integer,
	isbn char(13),
	asin char(10),
	leanpub varchar(30),
	apple integer,
	intro text,
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
	edited text,
	payable boolean
);
CREATE INDEX esqi ON essays(question_id);
CREATE INDEX eswi ON essays(writer_id);
CREATE INDEX esbi ON essays(book_id);
CREATE INDEX essa ON essays(started_at);
CREATE INDEX esfa ON essays(finished_at);
CREATE INDEX espy ON essays(payable);
CREATE INDEX esea ON essays(edited_at);


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
	their_filename text not null,
	our_filename text not null,
	mime_type varchar(32),
	bytes integer,
	uploaded char(1) NOT NULL DEFAULT 'n',
	duration varchar(7),
	status varchar(4) default 'new',
	notes text,
	transcription text
);

CREATE TABLE test_essays (
	id serial PRIMARY KEY,
	person_id integer not null REFERENCES peeps.people(id),
	country char(2) not null,
	question_id integer REFERENCES questions(id),
	started_at timestamp(0) with time zone,
	finished_at timestamp(0) with time zone,
	content text,
	notes text
);

COMMIT;

-- SELECT * FROM researcher_person WHERE id = 3;
CREATE VIEW researcher_person AS SELECT x.*,
	p.name, p.email, p.address, p.city, p.state, p.country
	FROM researchers x
	JOIN peeps.people p ON x.person_id=p.id;


-- SELECT * FROM writer_person WHERE id = 3;
CREATE VIEW writer_person AS SELECT x.*,
	p.name, p.email, p.address, p.city, p.state, p.country
	FROM writers x
	JOIN peeps.people p ON x.person_id=p.id;


-- SELECT * FROM customer_person WHERE id = 3;
CREATE VIEW customer_person AS SELECT x.*,
	p.name, p.email, p.address, p.city, p.state, p.country
	FROM customers x
	JOIN peeps.people p ON x.person_id=p.id;


-- SELECT * FROM editor_person WHERE id = 3;
CREATE VIEW editor_person AS SELECT x.*,
	p.name, p.email, p.address, p.city, p.state, p.country
	FROM editors x
	JOIN peeps.people p ON x.person_id=p.id;
