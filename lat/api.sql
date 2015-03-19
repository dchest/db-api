----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

-- PARAMS: concept.id
CREATE FUNCTION get_concept(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM lat.concepts_view WHERE id = $1) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS:  array of concept.ids
CREATE FUNCTION get_concepts(integer[], OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM lat.concepts_view WHERE id = ANY($1)) r;
	IF js IS NULL THEN js := '[]'; END IF; -- If none found, js is empty array
END;
$$ LANGUAGE plpgsql;


-- PARAMS: text of a new concept
CREATE FUNCTION create_concept(text, OUT mime text, OUT js json) AS $$
DECLARE
	new_id integer;
m4_ERRVARS
BEGIN
	INSERT INTO lat.concepts(concept) VALUES ($1) RETURNING id INTO new_id;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept(new_id) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PARAMS: concept.id, updated text
CREATE FUNCTION update_concept(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	UPDATE lat.concepts SET concept = $2 WHERE id = $1;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept($1) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PARAMS: concept.id
CREATE FUNCTION delete_concept(integer, OUT mime text, OUT js json) AS $$
BEGIN
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept($1) x;
	DELETE FROM lat.concepts WHERE id = $1;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: concept.id, text of tag
CREATE FUNCTION tag_concept(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	-- TODO: select to look for tag
	-- TODO: if not found, create it
	-- TODO: select to look in concepts_tags join table
	-- TODO: if not found, insert it
	INSERT INTO lat.tags (concept_id, tag) VALUES ($1, $2);
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concept($1) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PARAMS: url.id
CREATE FUNCTION get_url(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM lat.urls WHERE id = $1) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: concept.id, url, url.notes
CREATE FUNCTION add_url(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	uid integer;
m4_ERRVARS
BEGIN
	INSERT INTO lat.urls (url, notes) VALUES ($2, $3) RETURNING id INTO uid;
	INSERT INTO lat.concepts_urls (concept_id, url_id) VALUES ($1, uid);
	SELECT x.mime, x.js INTO mime, js FROM lat.get_url($1) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PARAMS: url.id, url, url.notes
CREATE FUNCTION update_url(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	UPDATE urls SET url=$2, notes=$3 WHERE id=$1;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_url($1) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PARAMS: url.id
CREATE FUNCTION delete_url(integer, OUT mime text, OUT js json) AS $$
BEGIN
	SELECT x.mime, x.js INTO mime, js FROM lat.get_url($1) x;
	DELETE FROM lat.urls WHERE id=$1;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: text of tag
-- Returns array of concepts or empty array if none found.
CREATE FUNCTION concepts_tagged(text, OUT mime text, OUT js json) AS $$
DECLARE
	ids integer[];
BEGIN
	SELECT array(SELECT concept_id FROM tags WHERE tag=$1) INTO ids;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_concepts(ids) x;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: pairing.id
CREATE FUNCTION get_pairing(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM
		(SELECT * FROM pairings_view WHERE id = $1) r;
m4_NOTFOUND
END;
$$ LANGUAGE plpgsql;


-- PARAMS: none. it's random
CREATE FUNCTION create_pairing(OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT id INTO pid FROM new_pairing();
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing(pid) x;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: pairing.id, updated thoughts
CREATE FUNCTION update_pairing(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	UPDATE pairings SET thoughts = $2 WHERE id = $1;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing($1) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PARAMS: pairing.id
CREATE FUNCTION delete_pairing(integer, OUT mime text, OUT js json) AS $$
BEGIN
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing($1) x;
	DELETE FROM pairings WHERE id = $1;
END;
$$ LANGUAGE plpgsql;


-- PARAMS: pairing.id, tag text
-- Adds that tag to both concepts in the pair
CREATE FUNCTION tag_pairing(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	-- TODO: select to look for tag
	-- TODO: if not found, create it
	-- TODO: select to look in concepts_tags join table
	-- TODO: if not found, insert it
	INSERT INTO tags SELECT concept1_id, $2 FROM pairings WHERE id = $1;
	INSERT INTO tags SELECT concept2_id, $2 FROM pairings WHERE id = $1;
	SELECT x.mime, x.js INTO mime, js FROM lat.get_pairing($1) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;

