--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = woodegg, pg_catalog;

--
-- Data for Name: topics; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

SET SESSION AUTHORIZATION DEFAULT;

ALTER TABLE topics DISABLE TRIGGER ALL;

INSERT INTO topics (id, topic) VALUES (1, 'Country');
INSERT INTO topics (id, topic) VALUES (2, 'Culture');


ALTER TABLE topics ENABLE TRIGGER ALL;

--
-- Data for Name: subtopics; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE subtopics DISABLE TRIGGER ALL;

INSERT INTO subtopics (id, topic_id, subtopic) VALUES (1, 1, 'how big');
INSERT INTO subtopics (id, topic_id, subtopic) VALUES (2, 1, 'how old');
INSERT INTO subtopics (id, topic_id, subtopic) VALUES (3, 2, 'is it fun?');
INSERT INTO subtopics (id, topic_id, subtopic) VALUES (4, 2, 'what language?');


ALTER TABLE subtopics ENABLE TRIGGER ALL;

--
-- Data for Name: template_questions; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE template_questions DISABLE TRIGGER ALL;

INSERT INTO template_questions (id, subtopic_id, question) VALUES (1, 1, 'how big is {COUNTRY}?');
INSERT INTO template_questions (id, subtopic_id, question) VALUES (2, 2, 'how old is {COUNTRY}?');
INSERT INTO template_questions (id, subtopic_id, question) VALUES (3, 3, 'what is fun in {COUNTRY}?');
INSERT INTO template_questions (id, subtopic_id, question) VALUES (4, 3, 'do they laugh in {COUNTRY}?');
INSERT INTO template_questions (id, subtopic_id, question) VALUES (5, 4, 'what language in {COUNTRY}?');


ALTER TABLE template_questions ENABLE TRIGGER ALL;

--
-- Data for Name: questions; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE questions DISABLE TRIGGER ALL;

INSERT INTO questions (id, template_question_id, country, question) VALUES (1, 1, 'CN', 'how big is China?');
INSERT INTO questions (id, template_question_id, country, question) VALUES (2, 2, 'CN', 'how old is China?');
INSERT INTO questions (id, template_question_id, country, question) VALUES (3, 3, 'CN', 'what is fun in China?');
INSERT INTO questions (id, template_question_id, country, question) VALUES (4, 4, 'CN', 'do they laugh in China?');
INSERT INTO questions (id, template_question_id, country, question) VALUES (5, 5, 'CN', 'what language in China?');
INSERT INTO questions (id, template_question_id, country, question) VALUES (6, 1, 'JP', 'how big is Japan?');
INSERT INTO questions (id, template_question_id, country, question) VALUES (7, 2, 'JP', 'how old is Japan?');
INSERT INTO questions (id, template_question_id, country, question) VALUES (8, 3, 'JP', 'what is fun in Japan?');
INSERT INTO questions (id, template_question_id, country, question) VALUES (9, 4, 'JP', 'do they laugh in Japan?');
INSERT INTO questions (id, template_question_id, country, question) VALUES (10, 5, 'JP', 'what language in Japan?');


ALTER TABLE questions ENABLE TRIGGER ALL;

--
-- Data for Name: researchers; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE researchers DISABLE TRIGGER ALL;

INSERT INTO researchers (id, person_id, bio) VALUES (1, 7, 'This is Gong Li');
INSERT INTO researchers (id, person_id, bio) VALUES (2, 8, 'This is Yoko Ono');
INSERT INTO researchers (id, person_id, bio) VALUES (3, 5, 'yes i am researching China');


ALTER TABLE researchers ENABLE TRIGGER ALL;

--
-- Data for Name: answers; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE answers DISABLE TRIGGER ALL;

INSERT INTO answers (id, question_id, researcher_id, started_at, finished_at, answer, sources) VALUES (1, 1, 1, '2013-06-28 20:16:40+12', '2013-06-28 20:26:40+12', 'China whatever1', 'none');
INSERT INTO answers (id, question_id, researcher_id, started_at, finished_at, answer, sources) VALUES (2, 2, 1, '2013-06-28 20:26:40+12', '2013-06-28 20:36:40+12', 'China whatever2', NULL);
INSERT INTO answers (id, question_id, researcher_id, started_at, finished_at, answer, sources) VALUES (3, 3, 1, '2013-06-28 20:36:40+12', '2013-06-28 20:46:40+12', 'China whatever3', NULL);
INSERT INTO answers (id, question_id, researcher_id, started_at, finished_at, answer, sources) VALUES (4, 4, 1, '2013-06-28 20:46:40+12', '2013-06-28 20:56:40+12', 'China whatever4', 'none');
INSERT INTO answers (id, question_id, researcher_id, started_at, finished_at, answer, sources) VALUES (5, 5, 1, '2013-06-28 20:56:40+12', '2013-06-28 21:06:40+12', 'China whatever5', NULL);
INSERT INTO answers (id, question_id, researcher_id, started_at, finished_at, answer, sources) VALUES (6, 6, 2, '2013-06-28 21:10:26+12', '2013-06-28 21:20:26+12', 'Japan it depends 6', 'mind');
INSERT INTO answers (id, question_id, researcher_id, started_at, finished_at, answer, sources) VALUES (7, 7, 2, '2013-06-28 21:20:26+12', '2013-06-28 21:30:26+12', 'Japan it depends 7', 'mind');
INSERT INTO answers (id, question_id, researcher_id, started_at, finished_at, answer, sources) VALUES (8, 8, 2, '2013-06-28 21:30:26+12', '2013-06-28 21:40:26+12', 'Japan blah blah. Unacceptable answer here.', NULL);
INSERT INTO answers (id, question_id, researcher_id, started_at, finished_at, answer, sources) VALUES (9, 9, 2, '2013-06-28 21:40:26+12', NULL, NULL, NULL);


ALTER TABLE answers ENABLE TRIGGER ALL;

--
-- Name: answers_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('answers_id_seq', 9, true);


--
-- Data for Name: books; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE books DISABLE TRIGGER ALL;

INSERT INTO books (id, country, code, title, pages, isbn, asin, leanpub, apple, salescopy, credits, available) VALUES (1, 'CN', 'we13cn', 'China 2013: How To', NULL, '9789810766320', 'B00D1HOJII', 'ChinaStartupGuide2013', NULL, 'THIS IS FOR SALE NOW', NULL, true);
INSERT INTO books (id, country, code, title, pages, isbn, asin, leanpub, apple, salescopy, credits, available) VALUES (2, 'JP', 'we13jp', 'Japan 2013: How To', NULL, '9789810766368', NULL, 'JapanStartupGuide2013', NULL, 'COMING SOON', NULL, false);
INSERT INTO books (id, country, code, title, pages, isbn, asin, leanpub, apple, salescopy, credits, available) VALUES (3, 'CN', 'we14cn', 'China 2014: How To', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);


ALTER TABLE books ENABLE TRIGGER ALL;

--
-- Data for Name: customers; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE customers DISABLE TRIGGER ALL;

INSERT INTO customers (id, person_id) VALUES (1, 6);


ALTER TABLE customers ENABLE TRIGGER ALL;

--
-- Data for Name: books_customers; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE books_customers DISABLE TRIGGER ALL;

INSERT INTO books_customers (book_id, customer_id) VALUES (1, 1);


ALTER TABLE books_customers ENABLE TRIGGER ALL;

--
-- Data for Name: editors; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE editors DISABLE TRIGGER ALL;

INSERT INTO editors (id, person_id, bio) VALUES (1, 1, 'This is Derek');
INSERT INTO editors (id, person_id, bio) VALUES (2, 2, 'This is Wonka');


ALTER TABLE editors ENABLE TRIGGER ALL;

--
-- Data for Name: books_editors; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE books_editors DISABLE TRIGGER ALL;

INSERT INTO books_editors (book_id, editor_id) VALUES (1, 1);
INSERT INTO books_editors (book_id, editor_id) VALUES (2, 2);


ALTER TABLE books_editors ENABLE TRIGGER ALL;

--
-- Name: books_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('books_id_seq', 3, true);


--
-- Data for Name: books_researchers; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE books_researchers DISABLE TRIGGER ALL;

INSERT INTO books_researchers (book_id, researcher_id) VALUES (1, 1);
INSERT INTO books_researchers (book_id, researcher_id) VALUES (2, 2);
INSERT INTO books_researchers (book_id, researcher_id) VALUES (3, 3);


ALTER TABLE books_researchers ENABLE TRIGGER ALL;

--
-- Data for Name: writers; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE writers DISABLE TRIGGER ALL;

INSERT INTO writers (id, person_id, bio) VALUES (1, 3, 'This is Veruca Salt');
INSERT INTO writers (id, person_id, bio) VALUES (2, 4, 'This is Charlie Buckets');


ALTER TABLE writers ENABLE TRIGGER ALL;

--
-- Data for Name: books_writers; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE books_writers DISABLE TRIGGER ALL;

INSERT INTO books_writers (book_id, writer_id) VALUES (1, 1);
INSERT INTO books_writers (book_id, writer_id) VALUES (2, 2);


ALTER TABLE books_writers ENABLE TRIGGER ALL;

--
-- Name: customers_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('customers_id_seq', 1, true);


--
-- Name: editors_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('editors_id_seq', 2, true);


--
-- Data for Name: essays; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE essays DISABLE TRIGGER ALL;

INSERT INTO essays (id, question_id, writer_id, book_id, editor_id, started_at, finished_at, edited_at, content, edited) VALUES (1, 1, 1, 1, 1, '2013-06-28 22:41:14+12', '2013-06-28 22:51:14+12', '2013-06-29 02:01:14+12', 'China whatever1?', 'China whatever1!');
INSERT INTO essays (id, question_id, writer_id, book_id, editor_id, started_at, finished_at, edited_at, content, edited) VALUES (2, 2, 1, 1, 1, '2013-06-28 22:51:14+12', '2013-06-28 23:01:14+12', '2013-06-29 02:11:14+12', 'China whatever2?', 'China whatever2!');
INSERT INTO essays (id, question_id, writer_id, book_id, editor_id, started_at, finished_at, edited_at, content, edited) VALUES (3, 3, 1, 1, 1, '2013-06-28 23:01:14+12', '2013-06-28 23:11:14+12', '2013-06-29 02:21:14+12', 'China .whatever3.', 'China whatever3');
INSERT INTO essays (id, question_id, writer_id, book_id, editor_id, started_at, finished_at, edited_at, content, edited) VALUES (4, 4, 1, 1, 1, '2013-06-28 23:11:14+12', '2013-06-28 23:21:14+12', '2013-06-29 02:31:14+12', 'China whatever4', 'China whatever4');
INSERT INTO essays (id, question_id, writer_id, book_id, editor_id, started_at, finished_at, edited_at, content, edited) VALUES (5, 5, 1, 1, 1, '2013-06-28 23:21:14+12', '2013-06-28 23:31:14+12', '2013-06-29 02:41:14+12', 'China? whatever5', 'China! whatever5');
INSERT INTO essays (id, question_id, writer_id, book_id, editor_id, started_at, finished_at, edited_at, content, edited) VALUES (6, 6, 2, 2, 2, '2013-07-08 22:41:14+12', '2013-07-08 22:51:14+12', '2013-07-10 02:41:14+12', 'Japan whatever1', 'Japan. Whatever. One.');
INSERT INTO essays (id, question_id, writer_id, book_id, editor_id, started_at, finished_at, edited_at, content, edited) VALUES (7, 7, 2, 2, 2, '2013-07-08 23:41:14+12', '2013-07-08 23:51:14+12', NULL, 'Japan whatever2', 'Editor still editing this one.');
INSERT INTO essays (id, question_id, writer_id, book_id, editor_id, started_at, finished_at, edited_at, content, edited) VALUES (8, 8, 2, 2, NULL, '2013-07-08 23:44:14+12', '2013-07-08 23:49:14+12', NULL, 'Japan finished but unjudged', NULL);
INSERT INTO essays (id, question_id, writer_id, book_id, editor_id, started_at, finished_at, edited_at, content, edited) VALUES (9, 9, 2, 2, NULL, '2013-07-08 23:52:14+12', NULL, NULL, 'Japan unfinished', NULL);


ALTER TABLE essays ENABLE TRIGGER ALL;

--
-- Name: essays_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('essays_id_seq', 9, true);


--
-- Name: questions_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('questions_id_seq', 10, true);


--
-- Data for Name: tidbits; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE tidbits DISABLE TRIGGER ALL;

INSERT INTO tidbits (id, created_at, created_by, headline, url, intro, content) VALUES (1, '2013-06-26', 'derek', 'Things looking good', 'http://www.cnn.com/article/123', 'Things sure are looking good', 'A long article about laughing and language in China here');
INSERT INTO tidbits (id, created_at, created_by, headline, url, intro, content) VALUES (2, '2013-06-27', 'derek', 'All is well', 'http://www.cnn.com/article/321', 'Things sure are well', 'A long article about how big and old Japan is');


ALTER TABLE tidbits ENABLE TRIGGER ALL;

--
-- Data for Name: questions_tidbits; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE questions_tidbits DISABLE TRIGGER ALL;

INSERT INTO questions_tidbits (question_id, tidbit_id) VALUES (4, 1);
INSERT INTO questions_tidbits (question_id, tidbit_id) VALUES (5, 1);
INSERT INTO questions_tidbits (question_id, tidbit_id) VALUES (6, 2);
INSERT INTO questions_tidbits (question_id, tidbit_id) VALUES (7, 2);


ALTER TABLE questions_tidbits ENABLE TRIGGER ALL;

--
-- Name: researchers_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('researchers_id_seq', 3, true);


--
-- Name: subtopics_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('subtopics_id_seq', 4, true);


--
-- Data for Name: tags; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE tags DISABLE TRIGGER ALL;

INSERT INTO tags (id, name) VALUES (1, 'China');
INSERT INTO tags (id, name) VALUES (2, 'Japan');


ALTER TABLE tags ENABLE TRIGGER ALL;

--
-- Name: tags_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('tags_id_seq', 2, true);


--
-- Data for Name: tags_tidbits; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE tags_tidbits DISABLE TRIGGER ALL;

INSERT INTO tags_tidbits (tag_id, tidbit_id) VALUES (1, 1);
INSERT INTO tags_tidbits (tag_id, tidbit_id) VALUES (2, 2);


ALTER TABLE tags_tidbits ENABLE TRIGGER ALL;

--
-- Name: template_questions_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('template_questions_id_seq', 5, true);


--
-- Data for Name: test_essays; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE test_essays DISABLE TRIGGER ALL;

INSERT INTO test_essays (id, person_id, country, question_id, started_at, finished_at, content, notes) VALUES (1, 8, 'JP', 6, '2013-09-05 01:08:44+12', '2013-09-05 02:56:40+12', 'good country', 'too succinct');
INSERT INTO test_essays (id, person_id, country, question_id, started_at, finished_at, content, notes) VALUES (2, 8, 'JP', 7, '2013-09-06 02:08:44+12', '2013-09-06 03:56:40+12', 'very good country', 'still too succinct');
INSERT INTO test_essays (id, person_id, country, question_id, started_at, finished_at, content, notes) VALUES (3, 6, 'CN', 1, '2013-09-06 22:08:44+12', '2013-09-07 00:56:40+12', 'das is huge', NULL);
INSERT INTO test_essays (id, person_id, country, question_id, started_at, finished_at, content, notes) VALUES (4, 6, 'CN', 2, '2013-09-07 01:08:44+12', NULL, NULL, NULL);


ALTER TABLE test_essays ENABLE TRIGGER ALL;

--
-- Name: test_essays_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('test_essays_id_seq', 4, true);


--
-- Name: tidbits_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('tidbits_id_seq', 2, true);


--
-- Name: topics_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('topics_id_seq', 2, true);


--
-- Data for Name: uploads; Type: TABLE DATA; Schema: woodegg; Owner: d50b
--

ALTER TABLE uploads DISABLE TRIGGER ALL;

INSERT INTO uploads (id, created_at, researcher_id, country, their_filename, our_filename, mime_type, bytes, duration, uploaded, status, notes, transcription) VALUES (1, '2013-08-07', 3, 'CN','Some Interview.MP3', 'r003-20130807-someinterview.mp3', 'audio/mp3', 1234567, '0:06:26', 'y', 'done', 'This is me interviewing someone.', 'This has a transcription.');
INSERT INTO uploads (id, created_at, researcher_id, country, their_filename, our_filename, mime_type, bytes, duration, uploaded, status, notes, transcription) VALUES (2, '2013-08-07', 3, 'CN','Another Interview.MP3', 'r003-20130807-anotherinterview.mp3', 'audio/mp3', 54321, NULL, 'p', 'new', 'Currently uploading', NULL);
INSERT INTO uploads (id, created_at, researcher_id, country, their_filename, our_filename, mime_type, bytes, duration, uploaded, status, notes, transcription) VALUES (3, '2013-08-08', 3, 'CN','Needs Notes.MP3', 'r003-20130808-needsnotes.mp3', 'audio/mp3', 654321, NULL, 'n', 'new', NULL, NULL);


ALTER TABLE uploads ENABLE TRIGGER ALL;

--
-- Name: uploads_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('uploads_id_seq', 3, true);


--
-- Name: writers_id_seq; Type: SEQUENCE SET; Schema: woodegg; Owner: d50b
--

SELECT pg_catalog.setval('writers_id_seq', 2, true);


--
-- PostgreSQL database dump complete
--

