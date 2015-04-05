--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = lat, pg_catalog;

--
-- Data for Name: concepts; Type: TABLE DATA; Schema: lat; Owner: d50b
--

SET SESSION AUTHORIZATION DEFAULT;

ALTER TABLE concepts DISABLE TRIGGER ALL;

INSERT INTO concepts (id, created_at, title, concept) VALUES (1, '2015-03-19', 'roses', 'roses are red');
INSERT INTO concepts (id, created_at, title, concept) VALUES (2, '2015-03-19', 'violets', 'violets are blue');
INSERT INTO concepts (id, created_at, title, concept) VALUES (3, '2015-03-19', 'sugar', 'sugar is sweet');
INSERT INTO concepts (id, created_at, title, concept) VALUES (4, '2015-04-06', 'tagless', 'has no tags');


ALTER TABLE concepts ENABLE TRIGGER ALL;

--
-- Name: concepts_id_seq; Type: SEQUENCE SET; Schema: lat; Owner: d50b
--

SELECT pg_catalog.setval('concepts_id_seq', 4, true);


--
-- Data for Name: tags; Type: TABLE DATA; Schema: lat; Owner: d50b
--

ALTER TABLE tags DISABLE TRIGGER ALL;

INSERT INTO tags (id, tag) VALUES (1, 'flower');
INSERT INTO tags (id, tag) VALUES (2, 'color');
INSERT INTO tags (id, tag) VALUES (3, 'flavor');


ALTER TABLE tags ENABLE TRIGGER ALL;

--
-- Data for Name: concepts_tags; Type: TABLE DATA; Schema: lat; Owner: d50b
--

ALTER TABLE concepts_tags DISABLE TRIGGER ALL;

INSERT INTO concepts_tags (concept_id, tag_id) VALUES (1, 1);
INSERT INTO concepts_tags (concept_id, tag_id) VALUES (2, 1);
INSERT INTO concepts_tags (concept_id, tag_id) VALUES (1, 2);
INSERT INTO concepts_tags (concept_id, tag_id) VALUES (2, 2);
INSERT INTO concepts_tags (concept_id, tag_id) VALUES (3, 3);


ALTER TABLE concepts_tags ENABLE TRIGGER ALL;

--
-- Data for Name: urls; Type: TABLE DATA; Schema: lat; Owner: d50b
--

ALTER TABLE urls DISABLE TRIGGER ALL;

INSERT INTO urls (id, url, notes) VALUES (1, 'http://www.rosesarered.co.nz/', NULL);
INSERT INTO urls (id, url, notes) VALUES (2, 'http://en.wikipedia.org/wiki/Roses_are_red', NULL);
INSERT INTO urls (id, url, notes) VALUES (3, 'http://en.wikipedia.org/wiki/Violets_Are_Blue', 'many refs here');


ALTER TABLE urls ENABLE TRIGGER ALL;

--
-- Data for Name: concepts_urls; Type: TABLE DATA; Schema: lat; Owner: d50b
--

ALTER TABLE concepts_urls DISABLE TRIGGER ALL;

INSERT INTO concepts_urls (concept_id, url_id) VALUES (1, 1);
INSERT INTO concepts_urls (concept_id, url_id) VALUES (1, 2);
INSERT INTO concepts_urls (concept_id, url_id) VALUES (2, 3);


ALTER TABLE concepts_urls ENABLE TRIGGER ALL;

--
-- Data for Name: pairings; Type: TABLE DATA; Schema: lat; Owner: d50b
--

ALTER TABLE pairings DISABLE TRIGGER ALL;

INSERT INTO pairings (id, created_at, concept1_id, concept2_id, thoughts) VALUES (1, '2015-03-19', 1, 2, 'describing flowers');


ALTER TABLE pairings ENABLE TRIGGER ALL;

--
-- Name: pairings_id_seq; Type: SEQUENCE SET; Schema: lat; Owner: d50b
--

SELECT pg_catalog.setval('pairings_id_seq', 1, true);


--
-- Name: tags_id_seq; Type: SEQUENCE SET; Schema: lat; Owner: d50b
--

SELECT pg_catalog.setval('tags_id_seq', 3, true);


--
-- Name: urls_id_seq; Type: SEQUENCE SET; Schema: lat; Owner: d50b
--

SELECT pg_catalog.setval('urls_id_seq', 3, true);


--
-- PostgreSQL database dump complete
--

