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
	IF cook IS NULL THEN m4_NOTFOUND ELSE
		mime := 'application/json';
		js := json_build_object('cookie', cook);
	END IF;
EXCEPTION WHEN OTHERS THEN m4_NOTFOUND
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
	IF js IS NULL THEN m4_NOTFOUND END IF;
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
	IF pid IS NULL THEN m4_NOTFOUND ELSE
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
m4_ERRVARS
BEGIN
	SELECT p.id, c.id INTO pid, cid
		FROM peeps.people p, woodegg.customers c
		WHERE p.newpass=$1
		AND p.id=c.person_id;
	IF pid IS NULL THEN m4_NOTFOUND ELSE
		PERFORM peeps.set_password(pid, $2);
		mime := 'application/json';
		-- this is just acknowledgement that it's done:
		js := row_to_json(r) FROM (SELECT id, name, email, address
			FROM peeps.people WHERE id=pid) r;
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- POST /register
-- PARAMS: name, email, password, proof
CREATE OR REPLACE FUNCTION register(text, text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
m4_ERRVARS
BEGIN
	SELECT id INTO pid FROM peeps.person_create_pass($1, $2, $3);
	INSERT INTO peeps.userstats(person_id, statkey, statvalue)
		VALUES (pid, 'proof-we14asia', $4);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT id, name, email, address
		FROM peeps.people WHERE id=pid) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- POST /forgot
-- PARAMS: email
CREATE OR REPLACE FUNCTION forgot(text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
	pnp text;
m4_ERRVARS
BEGIN
	SELECT p.id, p.newpass INTO pid, pnp FROM peeps.people p, woodegg.customers c
		WHERE p.id=c.person_id AND p.email = lower(regexp_replace($1, '\s', '', 'g'));
	IF pid IS NULL THEN m4_NOTFOUND ELSE
		IF pnp IS NULL THEN
			UPDATE peeps.people SET
			newpass = unique_for_table_field(8, 'peeps.people', 'newpass')
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
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /researchers/1
-- PARAMS: researcher_id
CREATE OR REPLACE FUNCTION get_researcher(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM researcher_view WHERE id=$1) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /writers/1
-- PARAMS: writer_id
CREATE OR REPLACE FUNCTION get_writer(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM writer_view WHERE id=$1) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /editors/1
-- PARAMS: editor_id
CREATE OR REPLACE FUNCTION get_editor(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM editor_view WHERE id=$1) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
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
	IF rowcount = 0 THEN m4_NOTFOUND RETURN; END IF;
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
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /books/23 
-- PARAMS: book id
CREATE OR REPLACE FUNCTION get_book(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM book_view WHERE id=$1) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
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
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /topics/5
-- PARAMS: topic id
CREATE OR REPLACE FUNCTION get_topic(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM templates_view WHERE id=$1) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /uploads/KR
-- PARAMS: country code
CREATE OR REPLACE FUNCTION get_uploads(text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM uploads_view WHERE country=$1) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /uploads/33
-- PARAMS: upload id#
CREATE OR REPLACE FUNCTION get_upload(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM upload_view WHERE id=$1) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;



