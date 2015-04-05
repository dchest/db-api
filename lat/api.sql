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
	IF js IS NULL THEN m4_NOTFOUND END IF;
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
m4_ERRVARS
BEGIN
	INSERT INTO lat.concepts(title, concept) VALUES ($1, $2) RETURNING id INTO new_id;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept(new_id) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PARAMS: concept.id, updated title, updated concept
CREATE OR REPLACE FUNCTION update_concept(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	UPDATE lat.concepts SET title=$2, concept=$3 WHERE id=$1;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept($1) x;
m4_ERRCATCH
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
m4_ERRVARS
BEGIN
	SELECT id INTO cid FROM lat.concepts WHERE id=$1;
	IF NOT FOUND THEN m4_NOTFOUND RETURN; END IF;
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
m4_ERRCATCH
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
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: concept.id, url, url.notes
CREATE OR REPLACE FUNCTION add_url(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	uid integer;
m4_ERRVARS
BEGIN
	INSERT INTO lat.urls (url, notes) VALUES ($2, $3) RETURNING id INTO uid;
	INSERT INTO lat.concepts_urls (concept_id, url_id) VALUES ($1, uid);
	SELECT x.mime, x.js INTO mime, js FROM lat.get_url(uid) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PARAMS: url.id, url, url.notes
CREATE OR REPLACE FUNCTION update_url(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	UPDATE lat.urls SET url=$2, notes=$3 WHERE id=$1;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_url($1) x;
m4_ERRCATCH
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
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: none. it's random
CREATE OR REPLACE FUNCTION create_pairing(OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
m4_ERRVARS
BEGIN
	SELECT id INTO pid FROM lat.new_pairing();
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing(pid) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PARAMS: pairing.id, updated thoughts
CREATE OR REPLACE FUNCTION update_pairing(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	UPDATE lat.pairings SET thoughts = $2 WHERE id = $1;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing($1) x;
m4_ERRCATCH
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
m4_ERRVARS
BEGIN
	SELECT concept1_id, concept2_id INTO id1, id2 FROM lat.pairings WHERE id=$1;
	PERFORM lat.tag_concept(id1, $2);
	PERFORM lat.tag_concept(id2, $2);
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing($1) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;

