----------------------------------------
------------------------- API FUNCTIONS:
----------------------------------------

-- API REQUIRES AUTHENTICATION. User must be in peeps.emailers
-- peeps.emailers.id needed as first argument to many functions here

-- PARAMS: email, password, API_name
CREATE OR REPLACE FUNCTION auth_api(text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM peeps.api_keys WHERE
			person_id=(SELECT id FROM peeps.person_email_pass($1, $2))
			AND $3=ANY(apis)) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /emails/unopened/count
-- Grouped summary of howmany unopened emails in each profile/category
-- JSON format: {profiles:{categories:howmany}}
--{"derek@sivers":{"derek@sivers":43,"derek":2,"programmer":1},
-- "we@woodegg":{"woodeggRESEARCH":1,"woodegg":1,"we@woodegg":1}}
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION unopened_email_count(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_object_agg(profile, cats) FROM (WITH unopened AS
		(SELECT profile, category FROM peeps.emails WHERE id IN
			(SELECT * FROM peeps.unopened_email_ids($1)))
		SELECT profile, (SELECT json_object_agg(category, num) FROM
			(SELECT category, COUNT(*) AS num FROM unopened u2
				WHERE u2.profile=unopened.profile
				GROUP BY category ORDER BY num DESC) rr)
		AS cats FROM unopened GROUP BY profile) r;  
	IF js IS NULL THEN
		js := '{}';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/unopened/:profile/:category
-- PARAMS: emailer_id, profile, category
CREATE OR REPLACE FUNCTION unopened_emails(integer, text, text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.emails_view WHERE id IN
		(SELECT id FROM peeps.emails WHERE id IN (SELECT * FROM peeps.unopened_email_ids($1))
			AND profile = $2 AND category = $3) ORDER BY id) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /emails/next/:profile/:category
-- Opens email (updates status as opened by this emailer) then returns view
-- PARAMS: emailer_id, profile, category
CREATE OR REPLACE FUNCTION open_next_email(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	SELECT id INTO eid FROM peeps.emails
		WHERE id IN (SELECT * FROM peeps.unopened_email_ids($1))
		AND profile=$2 AND category=$3 ORDER BY id LIMIT 1;
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		PERFORM open_email($1, eid);
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/opened
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION opened_emails(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.emails_view WHERE id IN
		(SELECT * FROM peeps.opened_email_ids($1)) ORDER BY id) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/:id
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION get_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := open_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id
-- PARAMS: emailer_id, email_id, JSON of new values
CREATE OR REPLACE FUNCTION update_email(integer, integer, json, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
m4_ERRVARS
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		PERFORM jsonupdate('peeps.emails', eid, $3,
			cols2update('peeps', 'emails', ARRAY['id', 'created_at']));
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /emails/:id
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION delete_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
		DELETE FROM peeps.emails WHERE id = eid;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/close
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION close_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE peeps.emails SET closed_at=NOW(), closed_by=$1 WHERE id = eid;
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/unread
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION unread_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE peeps.emails SET opened_at=NULL, opened_by=NULL WHERE id = eid;
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/notme
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION not_my_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE peeps.emails SET opened_at=NULL, opened_by=NULL, category=(SELECT
			substring(concat('not-', split_part(people.email,'@',1)) from 1 for 32)
			FROM peeps.emailers JOIN people ON emailers.person_id=people.id
			WHERE emailers.id = $1) WHERE id = eid;
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /emails/:id/reply?body=blah
-- PARAMS: emailer_id, email_id, body
CREATE OR REPLACE FUNCTION reply_to_email(integer, integer, text, OUT mime text, OUT js json) AS $$
DECLARE
	e emails;
	new_id integer;
m4_ERRVARS
BEGIN
	IF $3 IS NULL OR (regexp_replace($3, '\s', '', 'g') = '') THEN
		RAISE 'body must not be empty';
	END IF;
	SELECT * INTO e FROM peeps.emails WHERE id = ok_email($1, $2);
	IF e IS NULL THEN
m4_NOTFOUND
	ELSE
		-- PARAMS: emailer_id, person_id, profile, category, subject, body, reference_id 
		SELECT * INTO new_id FROM peeps.outgoing_email($1, e.person_id, e.profile, e.profile,
			concat('re: ', e.subject), $3, $2);
		UPDATE peeps.emails SET answer_id=new_id, closed_at=NOW(), closed_by=$1 WHERE id=$2;
		mime := 'application/json';
		js := row_to_json(r) FROM
			(SELECT * FROM peeps.email_view WHERE id = new_id) r;
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /unknowns/count
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION count_unknowns(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_build_object('count', (SELECT COUNT(*) FROM peeps.unknown_email_ids($1)));
END;
$$ LANGUAGE plpgsql;


-- GET /unknowns
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION get_unknowns(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.emails_view WHERE id IN
		(SELECT * FROM peeps.unknown_email_ids($1))) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /unknowns/next
-- PARAMS: emailer_id
CREATE OR REPLACE FUNCTION get_next_unknown(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.unknown_view WHERE id IN
		(SELECT * FROM peeps.unknown_email_ids($1) LIMIT 1)) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /unknowns/:id?person_id=123 or 0 to create new
-- PARAMS: emailer_id, email_id, person_id
CREATE OR REPLACE FUNCTION set_unknown_person(integer, integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	this_e emails;
	newperson people;
	rowcount integer;
m4_ERRVARS
BEGIN
	SELECT * INTO this_e FROM peeps.emails WHERE id IN
		(SELECT * FROM peeps.unknown_email_ids($1)) AND id = $2;
	GET DIAGNOSTICS rowcount = ROW_COUNT;
	IF rowcount = 0 THEN m4_NOTFOUND RETURN; END IF;
	IF $3 = 0 THEN
		SELECT * INTO newperson FROM peeps.person_create(this_e.their_name, this_e.their_email);
	ELSE
		SELECT * INTO newperson FROM peeps.people WHERE id = $3;
		GET DIAGNOSTICS rowcount = ROW_COUNT;
		IF rowcount = 0 THEN m4_NOTFOUND RETURN; END IF;
		UPDATE peeps.people SET email=this_e.their_email,
			notes = concat('OLD EMAIL: ', email, E'\n', notes) WHERE id = $3;
	END IF;
	UPDATE peeps.emails SET person_id=newperson.id, category=profile WHERE id = $2;
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.email_view WHERE id = $2) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /unknowns/:id
-- PARAMS: emailer_id, email_id
CREATE OR REPLACE FUNCTION delete_unknown(integer, integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.unknown_view
		WHERE id IN (SELECT * FROM peeps.unknown_email_ids($1)) AND id = $2) r;
	IF js IS NULL THEN
m4_NOTFOUND RETURN;
	ELSE
		DELETE FROM peeps.emails WHERE id = $2;
	END IF;
END;
$$ LANGUAGE plpgsql;

COMMIT;


-- POST /people
-- PARAMS: name, email
CREATE OR REPLACE FUNCTION create_person(text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
m4_ERRVARS
BEGIN
	SELECT id INTO pid FROM peeps.person_create($1, $2);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = pid) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/newpass
-- PARAMS: person_id
CREATE OR REPLACE FUNCTION make_newpass(integer, OUT mime text, OUT js json) AS $$
BEGIN
	UPDATE peeps.people
		SET newpass=peeps.unique_for_table_field(8, 'peeps.people', 'newpass')
		WHERE id=$1;
	IF FOUND THEN
		mime := 'application/json';
		js := json_build_object('id', $1);
	ELSE
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id
-- PARAMS: person_id
CREATE OR REPLACE FUNCTION get_person(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /people/:email
-- PARAMS: email
CREATE OR REPLACE FUNCTION get_person_email(text, OUT mime text, OUT js json) AS $$
DECLARE
	clean_email text;
BEGIN
	IF $1 IS NULL THEN m4_NOTFOUND END IF;
	clean_email := lower(regexp_replace($1, '\s', '', 'g'));
	IF clean_email !~ '\A\S+@\S+\.\S+\Z' THEN m4_NOTFOUND END IF;
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE email = clean_email) r;
	IF js IS NULL THEN m4_NOTFOUND END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id/:lopass
-- PARAMS: person_id, lopass
CREATE OR REPLACE FUNCTION get_person_lopass(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT id INTO pid FROM peeps.people WHERE id=$1 AND lopass=$2;
	IF pid IS NULL THEN
m4_NOTFOUND
	ELSE
		SELECT x.mime, x.js INTO mime, js FROM peeps.get_person($1) x;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id/:newpass
-- PARAMS: person_id, newpass
CREATE OR REPLACE FUNCTION get_person_newpass(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT id INTO pid FROM peeps.people WHERE id=$1 AND newpass=$2;
	IF pid IS NULL THEN
m4_NOTFOUND
	ELSE
		SELECT x.mime, x.js INTO mime, js FROM peeps.get_person($1) x;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /people?email=&password=
-- PARAMS: email, password
CREATE OR REPLACE FUNCTION get_person_password(text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT p.pid INTO pid FROM peeps.pid_from_email_pass($1, $2) p;
	IF pid IS NULL THEN
m4_NOTFOUND
	ELSE
		SELECT x.mime, x.js INTO mime, js FROM peeps.get_person(pid) x;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /person/{cookie}
-- PARAMS: cookie string
CREATE OR REPLACE FUNCTION get_person_cookie(text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT p.id INTO pid FROM peeps.get_person_from_cookie($1) p;
	IF pid IS NULL THEN
m4_NOTFOUND
	ELSE
		SELECT x.mime, x.js INTO mime, js FROM peeps.get_person(pid) x;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /login
-- PARAMS: person.id, domain
CREATE OR REPLACE FUNCTION cookie_from_id(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT cookie FROM peeps.login_person_domain($1, $2)) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- POST /login
-- PARAMS: email, password, domain
CREATE OR REPLACE FUNCTION cookie_from_login(text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
BEGIN
	SELECT p.pid INTO pid FROM peeps.pid_from_email_pass($1, $2) p;
	IF pid IS NULL THEN m4_NOTFOUND ELSE
		SELECT x.mime, x.js INTO mime, js FROM peeps.cookie_from_id(pid, $3) x;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /people/:id/password
-- PARAMS: person_id, password
CREATE OR REPLACE FUNCTION set_password(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM peeps.set_hashpass($1, $2);
	SELECT x.mime, x.js INTO mime, js FROM peeps.get_person($1) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- PUT /people/:id
-- PARAMS: person_id, JSON of new values
CREATE OR REPLACE FUNCTION update_person(integer, json, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM jsonupdate('peeps.people', $1, $2,
		cols2update('peeps', 'people', ARRAY['id', 'created_at']));
	SELECT x.mime, x.js INTO mime, js FROM peeps.get_person($1) x;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /people/:id
-- PARAMS: person_id
CREATE OR REPLACE FUNCTION delete_person(integer, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	ELSE
		DELETE FROM peeps.people WHERE id = $1;
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;

-- POST /people/:id/urls
-- PARAMS: person_id, url
CREATE OR REPLACE FUNCTION add_url(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	INSERT INTO urls(person_id, url) VALUES ($1, $2);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/stats
-- PARAMS: person_id, stat.name, stat.value
CREATE OR REPLACE FUNCTION add_stat(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	INSERT INTO userstats(person_id, statkey, statvalue) VALUES ($1, $2, $3);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/emails
-- PARAMS: emailer_id, person_id, profile, subject, body
CREATE OR REPLACE FUNCTION new_email(integer, integer, text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	new_id integer;
m4_ERRVARS
BEGIN
	-- PARAMS: emailer_id, person_id, profile, category, subject, body, reference_id (NULL unless reply)
	SELECT * INTO new_id FROM peeps.outgoing_email($1, $2, $3, $3, $4, $5, NULL);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.email_view WHERE id = new_id) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id/emails
-- PARAMS: person_id
CREATE OR REPLACE FUNCTION get_person_emails(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM
		(SELECT * FROM peeps.emails_full_view WHERE person_id = $1 ORDER BY id) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/merge?id=old_id
-- PARAMS: person_id to KEEP, person_id to CHANGE
CREATE OR REPLACE FUNCTION merge_person(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM person_merge_from_to($2, $1);
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /people/unmailed
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION people_unemailed(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view
		WHERE email_count = 0 ORDER BY id DESC LIMIT 200) r;
END;
$$ LANGUAGE plpgsql;


-- GET /search?q=term
-- PARAMS: search term
CREATE OR REPLACE FUNCTION people_search(text, OUT mime text, OUT js json) AS $$
DECLARE
	q text;
m4_ERRVARS
BEGIN
	q := concat('%', btrim($1, E'\t\r\n '), '%');
	IF LENGTH(q) < 4 THEN
		RAISE 'search term too short';
	END IF;
	mime := 'application/json';
	js := json_agg(r) FROM
		(SELECT * FROM peeps.people_view WHERE id IN (SELECT id FROM peeps.people
				WHERE name ILIKE q OR company ILIKE q OR email ILIKE q)
		ORDER BY email_count DESC, id DESC) r;
	IF js IS NULL THEN
		js := '{}';
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /stats/:id
-- PARAMS: stats.id
CREATE OR REPLACE FUNCTION get_stat(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.stats_view WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;



-- PUT /stat/:id
-- PARAMS: stats.id, json
CREATE OR REPLACE FUNCTION update_stat(integer, json, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM jsonupdate('peeps.userstats', $1, $2,
		cols2update('peeps', 'userstats', ARRAY['id', 'created_at']));
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.stats_view WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /stats/:id
-- PARAMS: stats.id
CREATE OR REPLACE FUNCTION delete_stat(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.stats_view WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	ELSE
		DELETE FROM peeps.userstats WHERE id = $1;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /urls/:id
-- PARAMS: urls.id
CREATE OR REPLACE FUNCTION get_url(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.urls WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- DELETE /urls/:id
-- PARAMS: urls.id
CREATE OR REPLACE FUNCTION delete_url(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.urls WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	ELSE
		DELETE FROM peeps.urls WHERE id = $1;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /urls/:id
-- PARAMS: urls.id, JSON with allowed: person_id::int, url::text, main::boolean
CREATE OR REPLACE FUNCTION update_url(integer, json, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM jsonupdate('peeps.urls', $1, $2,
		cols2update('peeps', 'urls', ARRAY['id']));
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.urls WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /formletters
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION get_formletters(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM
		(SELECT * FROM peeps.formletters_view ORDER BY title) r;
END;
$$ LANGUAGE plpgsql;


-- POST /formletters
-- PARAMS: title
CREATE OR REPLACE FUNCTION create_formletter(text, OUT mime text, OUT js json) AS $$
DECLARE
	new_id integer;
m4_ERRVARS
BEGIN
	INSERT INTO formletters(title) VALUES ($1) RETURNING id INTO new_id;
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM peeps.formletter_view WHERE id = new_id) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /formletters/:id
-- PARAMS: formletters.id
CREATE OR REPLACE FUNCTION get_formletter(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM peeps.formletter_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /formletters/:id
-- PARAMS: formletters.id, JSON keys: title, explanation, body
CREATE OR REPLACE FUNCTION update_formletter(integer, json, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM jsonupdate('peeps.formletters', $1, $2,
		cols2update('peeps', 'formletters', ARRAY['id', 'created_at']));
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM peeps.formletter_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /formletters/:id
-- PARAMS: formletters.id
CREATE OR REPLACE FUNCTION delete_formletter(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := row_to_json(r) FROM
		(SELECT * FROM peeps.formletter_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	ELSE
		DELETE FROM peeps.formletters WHERE id = $1;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- js = a simple JSON object: {"body": "The parsed text here, Derek."}
-- If wrong IDs given, value is null
-- GET /people/:id/formletters/:id
-- PARAMS: people.id, formletters.id
CREATE OR REPLACE FUNCTION parsed_formletter(integer, integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_build_object('body', parse_formletter_body($1, $2));
END;
$$ LANGUAGE plpgsql;


-- GET /locations
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION all_countries(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.countries ORDER BY name) r;
END;
$$ LANGUAGE plpgsql;


-- GET /country_names
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION country_names(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_object(
		ARRAY(SELECT code FROM countries ORDER BY code),
		ARRAY(SELECT name FROM countries ORDER BY code));
END;
$$ LANGUAGE plpgsql;


-- GET /countries
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION country_count(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT country, COUNT(*) FROM peeps.people
		WHERE country IS NOT NULL GROUP BY country ORDER BY COUNT(*) DESC, country) r;
END;
$$ LANGUAGE plpgsql;


-- GET /states/:country_code
-- PARAMS: 2-letter country code
CREATE OR REPLACE FUNCTION state_count(char(2), OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT state, COUNT(*) FROM peeps.people
		WHERE country = $1 AND state IS NOT NULL AND state != ''
		GROUP BY state ORDER BY COUNT(*) DESC, state) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /cities/:country_code/:state
-- PARAMS: 2-letter country code, state name
CREATE OR REPLACE FUNCTION city_count(char(2), text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT city, COUNT(*) FROM peeps.people
		WHERE country=$1 AND state=$2 AND (city IS NOT NULL AND city != '')
		GROUP BY city ORDER BY COUNT(*) DESC, city) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /cities/:country_code
-- PARAMS: 2-letter country code
CREATE OR REPLACE FUNCTION city_count(char(2), OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT city, COUNT(*) FROM peeps.people
		WHERE country=$1 AND (city IS NOT NULL AND city != '')
		GROUP BY city ORDER BY COUNT(*) DESC, city) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code
-- PARAMS: 2-letter country code
CREATE OR REPLACE FUNCTION people_from_country(char(2), OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code?state=XX
-- PARAMS: 2-letter country code, state
CREATE OR REPLACE FUNCTION people_from_state(char(2), text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1 AND state=$2)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code?city=XX
-- PARAMS: 2-letter country code, state
CREATE OR REPLACE FUNCTION people_from_city(char(2), text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1 AND city=$2)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code?city=XX&state=XX
-- PARAMS: 2-letter country code, state, city
CREATE OR REPLACE FUNCTION people_from_state_city(char(2), text, text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1 AND state=$2 AND city=$3)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;



-- GET /stats/:key/:value
-- PARAMS: stats.name, stats.value
CREATE OR REPLACE FUNCTION get_stats(text, text, OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.stats_view
		WHERE name = $1 AND value = $2) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /stats/:key
-- PARAMS: stats.name
CREATE OR REPLACE FUNCTION get_stats(text, OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT * FROM peeps.stats_view WHERE name = $1) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /statcount/:key
-- PARAMS: stats.name
CREATE OR REPLACE FUNCTION get_stat_value_count(text, OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT statvalue AS value, COUNT(*) AS count
		FROM peeps.userstats WHERE statkey=$1 GROUP BY statvalue ORDER BY statvalue) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /statcount
-- PARAMS: -none-
CREATE OR REPLACE FUNCTION get_stat_name_count(OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	js := json_agg(r) FROM (SELECT statkey AS name, COUNT(*) AS count
		FROM peeps.userstats GROUP BY statkey ORDER BY statkey) r;
END;
$$ LANGUAGE plpgsql;


-- POST /email
-- PARAMS: json of values to insert
-- KEYS: profile category message_id their_email their_name subject headers body
CREATE OR REPLACE FUNCTION import_email(json, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
	pid integer;
	rid integer;
m4_ERRVARS
BEGIN
	-- insert as-is (easier to update once in database)
	-- created_by = 2  TODO: created_by=NULL for imports?
	INSERT INTO peeps.emails(created_by, profile, category, message_id, their_email,
		their_name, subject, headers, body) SELECT 2 AS created_by, profile, category,
		message_id, their_email, their_name, subject, headers, body
		FROM json_populate_record(null::peeps.emails, $1) RETURNING id INTO eid;
	-- if references.message_id found, update person_id, reference_id, category
	IF json_array_length($1 -> 'references') > 0 THEN
		UPDATE peeps.emails SET person_id=ref.person_id, reference_id=ref.id,
			category = COALESCE(peeps.people.categorize_as, peeps.emails.profile)
			FROM peeps.emails ref, peeps.people
			WHERE peeps.emails.id=eid AND ref.person_id=peeps.people.id
			AND ref.message_id IN
				(SELECT * FROM json_array_elements_text($1 -> 'references'))
			RETURNING emails.person_id, ref.id INTO pid, rid;
		IF rid IS NOT NULL THEN
			UPDATE peeps.emails SET answer_id=eid WHERE id=rid;
		END IF;
	END IF;
	-- if their_email is found, update person_id, category
	IF pid IS NULL THEN
		UPDATE peeps.emails e SET person_id=p.id,
			category=COALESCE(p.categorize_as, e.profile)
			FROM peeps.people p WHERE e.id=eid
			AND (p.email=e.their_email OR p.company=e.their_email)
			RETURNING e.person_id INTO pid;
	END IF;
	-- if still not found, set category to fix-client (TODO: make this unnecessary)
	IF pid IS NULL THEN
		UPDATE peeps.emails SET category='fix-client' WHERE id=eid
			RETURNING person_id INTO pid;
	END IF;
	-- insert attachments
	IF json_array_length($1 -> 'attachments') > 0 THEN
		INSERT INTO email_attachments(email_id, mime_type, filename, bytes)
			SELECT eid AS email_id, mime_type, filename, bytes FROM
			json_populate_recordset(null::peeps.email_attachments, $1 -> 'attachments');
	END IF;
	mime := 'application/json';
	js := row_to_json(r) FROM (SELECT * FROM peeps.email_view WHERE id=eid) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- Update mailing list settings for this person (whether new or existing)
-- POST /list
-- PARAMS name, email, listype ($3 should be: 'all', 'some', 'none', or 'dead')
CREATE OR REPLACE FUNCTION list_update(text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
	clean3 text;
m4_ERRVARS
BEGIN
	clean3 := regexp_replace($3, '[^a-z]', '', 'g');
	SELECT id INTO pid FROM peeps.person_create($1, $2);
	INSERT INTO peeps.userstats(person_id, statkey, statvalue)
		VALUES (pid, 'listype', clean3);
	UPDATE peeps.people SET listype=clean3 WHERE id=pid;
	mime := 'application/json';
	js := json_build_object('list', clean3);
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


