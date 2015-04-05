SET client_min_messages TO ERROR;
DROP SCHEMA IF EXISTS lat CASCADE;
BEGIN;

CREATE SCHEMA lat;
SET search_path = lat;

CREATE TABLE concepts (
	id serial primary key,
	created_at date not null default CURRENT_DATE,
	title varchar(127) not null unique CONSTRAINT title_not_empty CHECK (length(title) > 0),
	concept text not null unique CONSTRAINT concept_not_empty CHECK (length(concept) > 0)
);

CREATE TABLE urls (
	id serial primary key,
	url text CONSTRAINT url_format CHECK (url ~ '^https?://[0-9a-zA-Z_-]+\.[a-zA-Z0-9]+'),
	notes text
);

CREATE TABLE tags (
	id serial primary key,
	tag varchar(32) not null unique CONSTRAINT emptytag CHECK (length(tag) > 0)
);

CREATE TABLE concepts_urls (
	concept_id integer not null references concepts(id) on delete cascade,
	url_id integer not null references urls(id) on delete cascade,
	primary key (concept_id, url_id)
);

CREATE TABLE concepts_tags (
	concept_id integer not null references concepts(id) on delete cascade,
	tag_id integer not null references tags(id) on delete cascade,
	primary key (concept_id, tag_id)
);

CREATE TABLE pairings (
	id serial primary key,
	created_at date not null default CURRENT_DATE,
	concept1_id integer not null references concepts(id) on delete cascade,
	concept2_id integer not null references concepts(id) on delete cascade,
	CHECK(concept1_id != concept2_id),
	UNIQUE(concept1_id, concept2_id),
	thoughts text
);

COMMIT;

----------------------------
------------------ TRIGGERS:
----------------------------

-- strip all line breaks, tabs, and spaces around title and concept before storing
CREATE OR REPLACE FUNCTION clean_concept() RETURNS TRIGGER AS $$
BEGIN
	NEW.title = btrim(regexp_replace(NEW.title, '\s+', ' ', 'g'));
	NEW.concept = btrim(regexp_replace(NEW.concept, '\s+', ' ', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_concept ON lat.concepts CASCADE;
CREATE TRIGGER clean_concept BEFORE INSERT OR UPDATE ON lat.concepts
	FOR EACH ROW EXECUTE PROCEDURE lat.clean_concept();


-- strip all line breaks, tabs, and spaces around url before storing (& validating)
CREATE OR REPLACE FUNCTION clean_url() RETURNS TRIGGER AS $$
BEGIN
	NEW.url = regexp_replace(NEW.url, '\s', '', 'g');
	NEW.notes = btrim(regexp_replace(NEW.notes, '\s+', ' ', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_url ON lat.urls CASCADE;
CREATE TRIGGER clean_url BEFORE INSERT OR UPDATE ON lat.urls
	FOR EACH ROW EXECUTE PROCEDURE lat.clean_url();


-- lowercase and strip all line breaks, tabs, and spaces around tag before storing
CREATE OR REPLACE FUNCTION clean_tag() RETURNS TRIGGER AS $$
BEGIN
	NEW.tag = lower(btrim(regexp_replace(NEW.tag, '\s+', ' ', 'g')));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_tag ON lat.tags CASCADE;
CREATE TRIGGER clean_tag BEFORE INSERT OR UPDATE OF tag ON lat.tags
	FOR EACH ROW EXECUTE PROCEDURE lat.clean_tag();


-- strip all line breaks, tabs, and spaces around thought before storing
CREATE OR REPLACE FUNCTION clean_pairing() RETURNS TRIGGER AS $$
BEGIN
	NEW.thoughts = btrim(regexp_replace(NEW.thoughts, '\s+', ' ', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_pairing ON lat.pairings CASCADE;
CREATE TRIGGER clean_pairing BEFORE INSERT OR UPDATE OF thoughts ON lat.pairings
	FOR EACH ROW EXECUTE PROCEDURE lat.clean_pairing();

----------------------------
----------------- FUNCTIONS:
----------------------------

-- create pairing of two concepts that haven't been paired before
CREATE FUNCTION new_pairing() RETURNS SETOF pairings AS $$
DECLARE
	id1 integer;
	id2 integer;
BEGIN
	SELECT c1.id, c2.id INTO id1, id2
		FROM lat.concepts c1 CROSS JOIN lat.concepts c2
		LEFT JOIN lat.pairings p ON (
			(c1.id=p.concept1_id AND c2.id=p.concept2_id) OR
			(c1.id=p.concept2_id AND c2.id=p.concept1_id)
		) WHERE c1.id != c2.id AND p.id IS NULL ORDER BY RANDOM();
	IF id1 IS NULL THEN
		RAISE EXCEPTION 'no unpaired concepts';
	END IF;
	RETURN QUERY INSERT INTO lat.pairings (concept1_id, concept2_id)
		VALUES (id1, id2) RETURNING *;
END;
$$ LANGUAGE plpgsql;

----------------------------------------
--------------- VIEWS FOR JSON RESPONSES:
----------------------------------------

DROP VIEW IF EXISTS concept_view CASCADE;
CREATE VIEW concept_view AS
	SELECT id, created_at, title, concept, (SELECT json_agg(uq) AS urls FROM
		(SELECT u.* FROM lat.urls u, lat.concepts_urls cu
			WHERE u.id=cu.url_id AND cu.concept_id=lat.concepts.id
			ORDER BY u.id) uq),
	(SELECT json_agg(tq) AS tags FROM
		(SELECT t.* FROM lat.tags t, lat.concepts_tags ct
			WHERE t.id=ct.tag_id AND ct.concept_id=concepts.id
			ORDER BY t.id) tq)
	FROM lat.concepts;

DROP VIEW IF EXISTS pairing_view CASCADE;
CREATE VIEW pairing_view AS
	SELECT id, created_at, thoughts,
		(SELECT row_to_json(c1) AS concept1 FROM
			(SELECT * FROM lat.concept_view WHERE id=lat.pairings.concept1_id) c1),
		(SELECT row_to_json(c2) AS concept2 FROM
			(SELECT * FROM lat.concept_view WHERE id=lat.pairings.concept2_id) c2)
	FROM lat.pairings;

----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

-- PARAMS: none
CREATE OR REPLACE FUNCTION get_concepts(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM lat.concepts ORDER BY id) r;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: concept.id
CREATE OR REPLACE FUNCTION get_concept(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM lat.concept_view WHERE id=$1) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS:  array of concept.ids
CREATE OR REPLACE FUNCTION get_concepts(integer[], OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM lat.concept_view WHERE id=ANY($1) ORDER BY id) r;
	IF js IS NULL THEN js := '[]'; END IF; -- If none found, js is empty array
END;
$$ LANGUAGE plpgsql;


-- PARAMS: title, concept
CREATE OR REPLACE FUNCTION create_concept(text, text, OUT mime text, OUT js json) AS $$
DECLARE
	new_id integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	INSERT INTO lat.concepts(title, concept) VALUES ($1, $2) RETURNING id INTO new_id;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept(new_id) x;

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


-- PARAMS: concept.id, updated title, updated concept
CREATE OR REPLACE FUNCTION update_concept(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	UPDATE lat.concepts SET title=$2, concept=$3 WHERE id=$1;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept($1) x;

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


-- PARAMS: concept.id
CREATE OR REPLACE FUNCTION delete_concept(integer, OUT mime text, OUT js json) AS $$
BEGIN
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept($1) x;
	DELETE FROM lat.concepts WHERE id = $1;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: concept.id, text of tag
CREATE OR REPLACE FUNCTION tag_concept(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
	cid integer;
	tid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT id INTO cid FROM lat.concepts WHERE id=$1;
	IF NOT FOUND THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 RETURN; END IF;
	SELECT id INTO tid FROM lat.tags
		WHERE tag = lower(btrim(regexp_replace($2, '\s+', ' ', 'g')));
	IF tid IS NULL THEN
		INSERT INTO lat.tags (tag) VALUES ($2) RETURNING id INTO tid;
	END IF;
	SELECT concept_id INTO cid FROM lat.concepts_tags WHERE concept_id=$1 AND tag_id=tid;
	IF NOT FOUND THEN
		INSERT INTO lat.concepts_tags(concept_id, tag_id) VALUES ($1, tid);
	END IF;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept($1) x;

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


-- PARAMS: concept.id, tag.id
CREATE OR REPLACE FUNCTION untag_concept(integer, integer, OUT mime text, OUT js json) AS $$
BEGIN
	DELETE FROM lat.concepts_tags WHERE concept_id=$1 AND tag_id=$2;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept($1) x;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: url.id
CREATE OR REPLACE FUNCTION get_url(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM lat.urls WHERE id = $1) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: concept.id, url, url.notes
CREATE OR REPLACE FUNCTION add_url(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	uid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	INSERT INTO lat.urls (url, notes) VALUES ($2, $3) RETURNING id INTO uid;
	INSERT INTO lat.concepts_urls (concept_id, url_id) VALUES ($1, uid);
	SELECT x.mime, x.js INTO mime, js FROM lat.get_url(uid) x;

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


-- PARAMS: url.id, url, url.notes
CREATE OR REPLACE FUNCTION update_url(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	UPDATE lat.urls SET url=$2, notes=$3 WHERE id=$1;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_url($1) x;

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


-- PARAMS: url.id
CREATE OR REPLACE FUNCTION delete_url(integer, OUT mime text, OUT js json) AS $$
BEGIN
	SELECT x.mime, x.js INTO mime, js FROM lat.get_url($1) x;
	DELETE FROM lat.urls WHERE id=$1;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: none
CREATE OR REPLACE FUNCTION tags(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM lat.tags ORDER BY RANDOM()) r;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: text of tag
-- Returns array of concepts or empty array if none found.
CREATE OR REPLACE FUNCTION concepts_tagged(text, OUT mime text, OUT js json) AS $$
BEGIN
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concepts(ARRAY(
		SELECT concept_id FROM lat.concepts_tags, lat.tags
		WHERE lat.tags.tag=$1 AND lat.tags.id=lat.concepts_tags.tag_id)) x;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: none
-- Returns array of concepts or empty array if none found.
CREATE OR REPLACE FUNCTION untagged_concepts(OUT mime text, OUT js json) AS $$
BEGIN
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concepts(ARRAY(
		SELECT lat.concepts.id FROM lat.concepts
		LEFT JOIN lat.concepts_tags ON lat.concepts.id=lat.concepts_tags.concept_id
		WHERE lat.concepts_tags.tag_id IS NULL)) x;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: none. all pairings.
CREATE OR REPLACE FUNCTION get_pairings(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT p.id, p.created_at,
		c1.title AS concept1, c2.title AS concept2
		FROM lat.pairings p LEFT JOIN lat.concepts c1 ON p.concept1_id=c1.id
		LEFT JOIN lat.concepts c2 ON p.concept2_id=c2.id ORDER BY p.id) r;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: pairing.id
CREATE OR REPLACE FUNCTION get_pairing(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM lat.pairing_view WHERE id=$1) r;
	IF js IS NULL THEN 
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
 END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: none. it's random
CREATE OR REPLACE FUNCTION create_pairing(OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT id INTO pid FROM lat.new_pairing();
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing(pid) x;

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


-- PARAMS: pairing.id, updated thoughts
CREATE OR REPLACE FUNCTION update_pairing(integer, text, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	UPDATE lat.pairings SET thoughts = $2 WHERE id = $1;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing($1) x;

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


-- PARAMS: pairing.id
CREATE OR REPLACE FUNCTION delete_pairing(integer, OUT mime text, OUT js json) AS $$
BEGIN
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing($1) x;
	DELETE FROM lat.pairings WHERE id = $1;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: pairing.id, tag text
-- Adds that tag to both concepts in the pair
CREATE OR REPLACE FUNCTION tag_pairing(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
	id1 integer;
	id2 integer;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT concept1_id, concept2_id INTO id1, id2 FROM lat.pairings WHERE id=$1;
	PERFORM lat.tag_concept(id1, $2);
	PERFORM lat.tag_concept(id2, $2);
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing($1) x;

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


