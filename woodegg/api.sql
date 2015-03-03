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
m4_NOTFOUND
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
m4_NOTFOUND
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
m4_NOTFOUND
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
-- GET /tidbits
