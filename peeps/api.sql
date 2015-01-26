-- API REQUIRES AUTHENTICATION. User must be in peeps.emailers
-- peeps.emailers.id needed as first argument to many functions here

-- GET /emails/unopened/count
-- Grouped summary of howmany unopened emails in each profile/category
-- JSON format: {profiles:{categories:howmany}}
--{"derek@sivers":{"derek@sivers":43,"derek":2,"programmer":1},
-- "we@woodegg":{"woodeggRESEARCH":1,"woodegg":1,"we@woodegg":1}}
-- PARAMS: emailer_id
CREATE FUNCTION unopened_email_count(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_object_agg(profile, cats) INTO js FROM (WITH unopened AS
		(SELECT profile, category FROM emails WHERE id IN
			(SELECT * FROM unopened_email_ids($1)))
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
CREATE FUNCTION unopened_emails(integer, text, text, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM emails_view WHERE id IN
		(SELECT id FROM emails WHERE id IN (SELECT * FROM unopened_email_ids($1))
			AND profile = $2 AND category = $3)) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /emails/next/:profile/:category
-- Opens email (updates status as opened by this emailer) then returns view
-- PARAMS: emailer_id, profile, category
CREATE FUNCTION open_next_email(integer, text, text, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	SELECT id INTO eid FROM emails
		WHERE id IN (SELECT * FROM unopened_email_ids($1))
		AND profile=$2 AND category=$3 LIMIT 1;
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		PERFORM open_email($1, eid);
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/opened
-- PARAMS: emailer_id
CREATE FUNCTION opened_emails(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM emails_view WHERE id IN
		(SELECT * FROM opened_email_ids($1))) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/:id
-- PARAMS: emailer_id, email_id
CREATE FUNCTION get_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := open_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id
-- PARAMS: emailer_id, email_id, JSON of new values
CREATE FUNCTION update_email(integer, integer, json, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
m4_ERRVARS
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		PERFORM public.jsonupdate('peeps.emails', eid, $3,
			public.cols2update('peeps', 'emails', ARRAY['id', 'created_at']));
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /emails/:id
-- PARAMS: emailer_id, email_id
CREATE FUNCTION delete_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
		DELETE FROM emails WHERE id = eid;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/close
-- PARAMS: emailer_id, email_id
CREATE FUNCTION close_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE emails SET closed_at=NOW(), closed_by=$1 WHERE id = eid;
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/unread
-- PARAMS: emailer_id, email_id
CREATE FUNCTION unread_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE emails SET opened_at=NULL, opened_by=NULL WHERE id = eid;
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/notme
-- PARAMS: emailer_id, email_id
CREATE FUNCTION not_my_email(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE emails SET opened_at=NULL, opened_by=NULL, category=(SELECT
			substring(concat('not-', split_part(people.email,'@',1)) from 1 for 32)
			FROM emailers JOIN people ON emailers.person_id=people.id
			WHERE emailers.id = $1) WHERE id = eid;
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /emails/:id/reply?body=blah
-- PARAMS: emailer_id, email_id, body
CREATE FUNCTION reply_to_email(integer, integer, text, OUT mime text, OUT js text) AS $$
DECLARE
	e emails;
	new_id integer;
m4_ERRVARS
BEGIN
	IF $3 IS NULL OR (regexp_replace($3, '\s', '', 'g') = '') THEN
		RAISE 'body must not be empty';
	END IF;
	SELECT * INTO e FROM emails WHERE id = ok_email($1, $2);
	IF e IS NULL THEN
m4_NOTFOUND
	ELSE
		-- PARAMS: emailer_id, person_id, profile, category, subject, body, reference_id 
		SELECT * INTO new_id FROM outgoing_email($1, e.person_id, e.profile, e.profile,
			concat('re: ', e.subject), $3, $2);
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM email_view WHERE id = new_id) r;
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /unknowns
-- PARAMS: emailer_id
CREATE FUNCTION get_unknowns(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM emails_view WHERE id IN
		(SELECT * FROM unknown_email_ids($1))) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /unknowns/next
-- PARAMS: emailer_id
CREATE FUNCTION get_next_unknown(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM unknown_view WHERE id IN
		(SELECT * FROM unknown_email_ids($1) LIMIT 1)) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /unknowns/:id?person_id=123 or 0 to create new
-- PARAMS: emailer_id, email_id, person_id
CREATE FUNCTION set_unknown_person(integer, integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
	this_e emails;
	newperson people;
	rowcount integer;
m4_ERRVARS
BEGIN
	SELECT * INTO this_e FROM emails WHERE id IN
		(SELECT * FROM unknown_email_ids($1)) AND id = $2;
	GET DIAGNOSTICS rowcount = ROW_COUNT;
	IF rowcount = 0 THEN m4_NOTFOUND RETURN; END IF;
	IF $3 = 0 THEN
		SELECT * INTO newperson FROM person_create(this_e.their_name, this_e.their_email);
	ELSE
		SELECT * INTO newperson FROM people WHERE id = $3;
		GET DIAGNOSTICS rowcount = ROW_COUNT;
		IF rowcount = 0 THEN m4_NOTFOUND RETURN; END IF;
		UPDATE people SET email=this_e.their_email,
			notes = concat('OLD EMAIL: ', email, E'\n', notes) WHERE id = $3;
	END IF;
	UPDATE emails SET person_id=newperson.id, category=profile WHERE id = $2;
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM email_view WHERE id = $2) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /unknowns/:id
-- PARAMS: emailer_id, email_id
CREATE FUNCTION delete_unknown(integer, integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM unknown_view
		WHERE id IN (SELECT * FROM unknown_email_ids($1)) AND id = $2) r;
	IF js IS NULL THEN
m4_NOTFOUND RETURN;
	ELSE
		DELETE FROM emails WHERE id = $2;
	END IF;
END;
$$ LANGUAGE plpgsql;

COMMIT;


-- POST /people
-- PARAMS: name, text
CREATE FUNCTION create_person(text, text, OUT mime text, OUT js text) AS $$
DECLARE
	pid integer;
m4_ERRVARS
BEGIN
	SELECT id INTO pid FROM person_create($1, $2);
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM person_view WHERE id = pid) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id
-- PARAMS: person_id
CREATE FUNCTION get_person(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM person_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /people/:id
-- PARAMS: person_id, JSON of new values
CREATE FUNCTION update_person(integer, json, OUT mime text, OUT js text) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM public.jsonupdate('peeps.people', $1, $2,
		public.cols2update('peeps', 'people', ARRAY['id', 'created_at']));
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM person_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /people/:id
-- PARAMS: person_id
CREATE FUNCTION delete_person(integer, OUT mime text, OUT js text) AS $$
DECLARE
m4_ERRVARS
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM person_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	ELSE
		DELETE FROM people WHERE id = $1;
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;

-- POST /people/:id/urls
-- PARAMS: person_id, url
CREATE FUNCTION add_url(integer, text, OUT mime text, OUT js text) AS $$
DECLARE
m4_ERRVARS
BEGIN
	INSERT INTO urls(person_id, url) VALUES ($1, $2);
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM person_view WHERE id = $1) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/stats
-- PARAMS: person_id, stat.name, stat.value
CREATE FUNCTION add_stat(integer, text, text, OUT mime text, OUT js text) AS $$
DECLARE
m4_ERRVARS
BEGIN
	INSERT INTO userstats(person_id, statkey, statvalue) VALUES ($1, $2, $3);
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM person_view WHERE id = $1) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/emails
-- PARAMS: emailer_id, person_id, profile, subject, body
CREATE FUNCTION new_email(integer, integer, text, text, text, OUT mime text, OUT js text) AS $$
DECLARE
	new_id integer;
m4_ERRVARS
BEGIN
	-- PARAMS: emailer_id, person_id, profile, category, subject, body, reference_id (NULL unless reply)
	SELECT * INTO new_id FROM outgoing_email($1, $2, $3, $3, $4, $5, NULL);
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM email_view WHERE id = new_id) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id/emails
-- PARAMS: person_id
CREATE FUNCTION get_person_emails(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM
		(SELECT * FROM emails_full_view WHERE person_id = $1 ORDER BY id) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/merge?id=old_id
-- PARAMS: person_id to KEEP, person_id to CHANGE
CREATE FUNCTION merge_person(integer, integer, OUT mime text, OUT js text) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM person_merge_from_to($2, $1);
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM person_view WHERE id = $1) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /people/unmailed
-- PARAMS: -none-
CREATE FUNCTION people_unemailed(OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM people_view
		WHERE email_count = 0 ORDER BY id DESC LIMIT 200) r;
END;
$$ LANGUAGE plpgsql;


