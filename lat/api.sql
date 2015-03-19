----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

-- USAGE: SELECT mime, js FROM get_concept(123);
-- JSON format for all *_concept functions below:
-- {"id":1,"created_at":"2015-01-17","concept":"roses are red","tags":["flower","color"]}
CREATE FUNCTION get_concept(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM
		(SELECT * FROM concepts_view WHERE id = $1) r;
NOTFOUND
END;
$$ LANGUAGE plpgsql;

-- give it an array of concept.ids.  Keep JSON format same as get_concept, but in array.
-- If none found, js is empty array
CREATE FUNCTION get_concepts(integer[], OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM
		(SELECT * FROM concepts_view WHERE id = ANY($1)) r;
	IF js IS NULL THEN
		js := array_to_json(array[]::text[]);
	END IF;
END;
$$ LANGUAGE plpgsql;

-- USAGE: SELECT mime, js FROM create_concept('some text here');
CREATE FUNCTION create_concept(text, OUT mime text, OUT js text) AS $$
DECLARE
	new_id integer;
ERRVARS
BEGIN
	INSERT INTO concepts(concept) VALUES ($1) RETURNING id INTO new_id;
	SELECT x.mime, x.js INTO mime, js FROM get_concept(new_id) x;
ERRCATCH
END;
$$ LANGUAGE plpgsql;

-- USAGE: SELECT mime, js FROM update_concept(123, 'new text here');
CREATE FUNCTION update_concept(integer, text, OUT mime text, OUT js text) AS $$
DECLARE
ERRVARS
BEGIN
	UPDATE concepts SET concept = $2 WHERE id = $1;
	SELECT x.mime, x.js INTO mime, js FROM get_concept($1) x;
ERRCATCH
END;
$$ LANGUAGE plpgsql;

-- USAGE: SELECT mime, js FROM delete_concept(123);
CREATE FUNCTION delete_concept(integer, OUT mime text, OUT js text) AS $$
BEGIN
	SELECT x.mime, x.js INTO mime, js FROM get_concept($1) x;
	DELETE FROM concepts WHERE id = $1;
END;
$$ LANGUAGE plpgsql;

-- USAGE: SELECT mime, js FROM tag_concept(123, 'newtag');
CREATE FUNCTION tag_concept(integer, text, OUT mime text, OUT js text) AS $$
DECLARE
ERRVARS
BEGIN
	INSERT INTO tags (concept_id, tag) VALUES ($1, $2);
	SELECT x.mime, x.js INTO mime, js FROM get_concept($1) x;
ERRCATCH
END;
$$ LANGUAGE plpgsql;

-- USAGE: SELECT mime, js FROM concepts_tagged('tagname');
-- Returns array of concepts or empty array if none found.
CREATE FUNCTION concepts_tagged(text, OUT mime text, OUT js text) AS $$
DECLARE
	ids integer[];
BEGIN
	SELECT array(SELECT concept_id FROM tags WHERE tag=$1) INTO ids;
	SELECT x.mime, x.js INTO mime, js FROM get_concepts(ids) x;
END;
$$ LANGUAGE plpgsql;

-- USAGE: SELECT mime, js FROM get_pairing(123);
-- {"id":1,"created_at":"2015-01-17","thoughts":"paired thoughts here","concepts":[{array of concepts with keys: id, concept, tags}]}
CREATE FUNCTION get_pairing(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM
		(SELECT * FROM pairings_view WHERE id = $1) r;
NOTFOUND
END;
$$ LANGUAGE plpgsql;

-- USAGE: SELECT mime, js FROM create_pairing();
-- TODO: what to do when there are no pairings left?
CREATE FUNCTION create_pairing(OUT mime text, OUT js text) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT id INTO pid FROM new_pairing();
	SELECT x.mime, x.js INTO mime, js FROM get_pairing(pid) x;
END;
$$ LANGUAGE plpgsql;

-- USAGE: SELECT mime, js FROM update_pairing(3, 'new thoughts here');
CREATE FUNCTION update_pairing(integer, text, OUT mime text, OUT js text) AS $$
DECLARE
ERRVARS
BEGIN
	UPDATE pairings SET thoughts = $2 WHERE id = $1;
	SELECT x.mime, x.js INTO mime, js FROM get_pairing($1) x;
ERRCATCH
END;
$$ LANGUAGE plpgsql;

-- USAGE: SELECT mime, js FROM delete_pairing(123);
CREATE FUNCTION delete_pairing(integer, OUT mime text, OUT js text) AS $$
BEGIN
	SELECT x.mime, x.js INTO mime, js FROM get_pairing($1) x;
	DELETE FROM pairings WHERE id = $1;
END;
$$ LANGUAGE plpgsql;

-- USAGE: SELECT mime, js FROM tag_pairing(2, 'newtag');
-- Adds that tag to both concepts in the pair
CREATE FUNCTION tag_pairing(integer, text, OUT mime text, OUT js text) AS $$
DECLARE
ERRVARS
BEGIN
	INSERT INTO tags SELECT concept1_id, $2 FROM pairings WHERE id = $1;
	INSERT INTO tags SELECT concept2_id, $2 FROM pairings WHERE id = $1;
	SELECT x.mime, x.js INTO mime, js FROM get_pairing($1) x;
ERRCATCH
END;
$$ LANGUAGE plpgsql;

