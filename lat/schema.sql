SET client_min_messages TO ERROR;
DROP SCHEMA IF EXISTS lat CASCADE;
BEGIN;

CREATE SCHEMA lat;
SET search_path = lat;

CREATE TABLE concepts (
	id serial primary key,
	created_at date not null default CURRENT_DATE,
	title varchar(127),
	concept text
);

CREATE TABLE urls (
	id serial primary key,
	url text CONSTRAINT url_format CHECK (url ~ '^https?://[0-9a-zA-Z_-]+\.[a-zA-Z0-9]+'),
	notes text
);

CREATE TABLE tags (
	id serial primary key,
	tag varchar(32) unique not null CONSTRAINT emptytag CHECK (length(tag) > 0)
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

-- strip all line breaks, tabs, and spaces around concept before storing
CREATE OR REPLACE FUNCTION clean_concept() RETURNS TRIGGER AS $$
BEGIN
	NEW.concept = btrim(regexp_replace(NEW.concept, '\s+', ' ', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_concept ON lat.concepts CASCADE;
CREATE TRIGGER clean_concept BEFORE INSERT OR UPDATE OF concept ON lat.concepts FOR EACH ROW EXECUTE PROCEDURE clean_concept();


-- lowercase and strip all line breaks, tabs, and spaces around tag before storing
CREATE OR REPLACE FUNCTION clean_tag() RETURNS TRIGGER AS $$
BEGIN
	NEW.tag = lower(btrim(regexp_replace(NEW.tag, '\s+', ' ', 'g')));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_tag ON lat.tags CASCADE;
CREATE TRIGGER clean_tag BEFORE INSERT OR UPDATE OF tag ON lat.tags FOR EACH ROW EXECUTE PROCEDURE clean_tag();

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
		FROM concepts c1 CROSS JOIN concepts c2
		LEFT JOIN pairings p ON (
			(c1.id=p.concept1_id AND c2.id=p.concept2_id) OR
			(c1.id=p.concept2_id AND c2.id=p.concept1_id)
		) WHERE c1.id != c2.id AND p.id IS NULL ORDER BY RANDOM();
	IF id1 IS NULL THEN
		RAISE EXCEPTION 'no unpaired concepts';
	END IF;
	RETURN QUERY INSERT INTO pairings (concept1_id, concept2_id)
		VALUES (id1, id2) RETURNING *;
END;
$$ LANGUAGE plpgsql;

----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

-- PARAMS: concept.id
CREATE OR REPLACE FUNCTION get_concept(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM lat.concepts WHERE id = $1) r;
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
	js := json_agg(r) FROM (SELECT * FROM lat.concepts WHERE id = ANY($1)) r;
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
	tid integer;
	ct lat.concepts_tags;

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	SELECT id INTO tid FROM lat.tags
		WHERE tag = lower(btrim(regexp_replace($2, '\s+', ' ', 'g')));
	IF tid IS NULL THEN
		INSERT INTO lat.tags (tag) VALUES ($2) RETURNING id INTO tid;
	END IF;
	SELECT * INTO ct FROM lat.concepts_tags WHERE concept_id=$1 AND tag_id=tid;
	IF ct IS NULL THEN
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


-- PARAMS: url.id, url, url.notes
CREATE OR REPLACE FUNCTION update_url(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE

	err_code text;
	err_msg text;
	err_detail text;
	err_context text;

BEGIN
	UPDATE urls SET url=$2, notes=$3 WHERE id=$1;
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


-- PARAMS: text of tag
-- Returns array of concepts or empty array if none found.
CREATE OR REPLACE FUNCTION concepts_tagged(text, OUT mime text, OUT js json) AS $$
DECLARE
	ids integer[];
BEGIN
	SELECT array(SELECT concept_id FROM lat.concepts_tags, lat.tags
		WHERE lat.tags.tag=$1 AND lat.tags.id=lat.concepts_tags.tag_id) INTO ids;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concepts(ids) x;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: pairing.id
CREATE OR REPLACE FUNCTION get_pairing(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM lat.pairings WHERE id=$1) r;
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


