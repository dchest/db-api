-- API REQUIRES AUTHENTICATION. User must be in peeps.emailers
-- peeps.emailers.id needed as first argument to many functions here

-- PARAMS: email, password, API_name
DROP FUNCTION IF EXISTS auth_api(text, text, text) CASCADE;
CREATE FUNCTION auth_api(text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM
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
DROP FUNCTION IF EXISTS unopened_email_count(integer) CASCADE;
CREATE FUNCTION unopened_email_count(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_object_agg(profile, cats) INTO js FROM (WITH unopened AS
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
DROP FUNCTION IF EXISTS unopened_emails(integer, text, text) CASCADE;
CREATE FUNCTION unopened_emails(integer, text, text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.emails_view WHERE id IN
		(SELECT id FROM peeps.emails WHERE id IN (SELECT * FROM peeps.unopened_email_ids($1))
			AND profile = $2 AND category = $3)) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /emails/next/:profile/:category
-- Opens email (updates status as opened by this emailer) then returns view
-- PARAMS: emailer_id, profile, category
DROP FUNCTION IF EXISTS open_next_email(integer, text, text) CASCADE;
CREATE FUNCTION open_next_email(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	SELECT id INTO eid FROM peeps.emails
		WHERE id IN (SELECT * FROM peeps.unopened_email_ids($1))
		AND profile=$2 AND category=$3 LIMIT 1;
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		PERFORM open_email($1, eid);
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/opened
-- PARAMS: emailer_id
DROP FUNCTION IF EXISTS opened_emails(integer) CASCADE;
CREATE FUNCTION opened_emails(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.emails_view WHERE id IN
		(SELECT * FROM peeps.opened_email_ids($1))) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /emails/:id
-- PARAMS: emailer_id, email_id
DROP FUNCTION IF EXISTS get_email(integer, integer) CASCADE;
CREATE FUNCTION get_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := open_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id
-- PARAMS: emailer_id, email_id, JSON of new values
DROP FUNCTION IF EXISTS update_email(integer, integer, json) CASCADE;
CREATE FUNCTION update_email(integer, integer, json, OUT mime text, OUT js json) AS $$
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
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /emails/:id
-- PARAMS: emailer_id, email_id
DROP FUNCTION IF EXISTS delete_email(integer, integer) CASCADE;
CREATE FUNCTION delete_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
		DELETE FROM peeps.emails WHERE id = eid;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/close
-- PARAMS: emailer_id, email_id
DROP FUNCTION IF EXISTS close_email(integer, integer) CASCADE;
CREATE FUNCTION close_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE peeps.emails SET closed_at=NOW(), closed_by=$1 WHERE id = eid;
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/unread
-- PARAMS: emailer_id, email_id
DROP FUNCTION IF EXISTS unread_email(integer, integer) CASCADE;
CREATE FUNCTION unread_email(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
	eid integer;
BEGIN
	eid := ok_email($1, $2);
	IF eid IS NULL THEN
m4_NOTFOUND
	ELSE
		UPDATE peeps.emails SET opened_at=NULL, opened_by=NULL WHERE id = eid;
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /emails/:id/notme
-- PARAMS: emailer_id, email_id
DROP FUNCTION IF EXISTS not_my_email(integer, integer) CASCADE;
CREATE FUNCTION not_my_email(integer, integer, OUT mime text, OUT js json) AS $$
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
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM peeps.email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /emails/:id/reply?body=blah
-- PARAMS: emailer_id, email_id, body
DROP FUNCTION IF EXISTS reply_to_email(integer, integer, text) CASCADE;
CREATE FUNCTION reply_to_email(integer, integer, text, OUT mime text, OUT js json) AS $$
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
		SELECT row_to_json(r) INTO js FROM
			(SELECT * FROM peeps.email_view WHERE id = new_id) r;
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /unknowns/count
-- PARAMS: emailer_id
DROP FUNCTION IF EXISTS count_unknowns(integer) CASCADE;
CREATE FUNCTION count_unknowns(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_build_object('count', (SELECT COUNT(*) FROM peeps.unknown_email_ids($1)));
END;
$$ LANGUAGE plpgsql;


-- GET /unknowns
-- PARAMS: emailer_id
DROP FUNCTION IF EXISTS get_unknowns(integer) CASCADE;
CREATE FUNCTION get_unknowns(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.emails_view WHERE id IN
		(SELECT * FROM peeps.unknown_email_ids($1))) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /unknowns/next
-- PARAMS: emailer_id
DROP FUNCTION IF EXISTS get_next_unknown(integer) CASCADE;
CREATE FUNCTION get_next_unknown(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.unknown_view WHERE id IN
		(SELECT * FROM peeps.unknown_email_ids($1) LIMIT 1)) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /unknowns/:id?person_id=123 or 0 to create new
-- PARAMS: emailer_id, email_id, person_id
DROP FUNCTION IF EXISTS set_unknown_person(integer, integer, integer) CASCADE;
CREATE FUNCTION set_unknown_person(integer, integer, integer, OUT mime text, OUT js json) AS $$
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
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.email_view WHERE id = $2) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /unknowns/:id
-- PARAMS: emailer_id, email_id
DROP FUNCTION IF EXISTS delete_unknown(integer, integer) CASCADE;
CREATE FUNCTION delete_unknown(integer, integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.unknown_view
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
DROP FUNCTION IF EXISTS create_person(text, text) CASCADE;
CREATE FUNCTION create_person(text, text, OUT mime text, OUT js json) AS $$
DECLARE
	pid integer;
m4_ERRVARS
BEGIN
	SELECT id INTO pid FROM peeps.person_create($1, $2);
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.person_view WHERE id = pid) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id
-- PARAMS: person_id
DROP FUNCTION IF EXISTS get_person(integer) CASCADE;
CREATE FUNCTION get_person(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /people/:id
-- PARAMS: person_id, JSON of new values
DROP FUNCTION IF EXISTS update_person(integer, json) CASCADE;
CREATE FUNCTION update_person(integer, json, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM public.jsonupdate('peeps.people', $1, $2,
		public.cols2update('peeps', 'people', ARRAY['id', 'created_at']));
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /people/:id
-- PARAMS: person_id
DROP FUNCTION IF EXISTS delete_person(integer) CASCADE;
CREATE FUNCTION delete_person(integer, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
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
DROP FUNCTION IF EXISTS add_url(integer, text) CASCADE;
CREATE FUNCTION add_url(integer, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	INSERT INTO urls(person_id, url) VALUES ($1, $2);
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/stats
-- PARAMS: person_id, stat.name, stat.value
DROP FUNCTION IF EXISTS add_stat(integer, text, text) CASCADE;
CREATE FUNCTION add_stat(integer, text, text, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	INSERT INTO userstats(person_id, statkey, statvalue) VALUES ($1, $2, $3);
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/emails
-- PARAMS: emailer_id, person_id, profile, subject, body
DROP FUNCTION IF EXISTS new_email(integer, integer, text, text, text) CASCADE;
CREATE FUNCTION new_email(integer, integer, text, text, text, OUT mime text, OUT js json) AS $$
DECLARE
	new_id integer;
m4_ERRVARS
BEGIN
	-- PARAMS: emailer_id, person_id, profile, category, subject, body, reference_id (NULL unless reply)
	SELECT * INTO new_id FROM peeps.outgoing_email($1, $2, $3, $3, $4, $5, NULL);
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.email_view WHERE id = new_id) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /people/:id/emails
-- PARAMS: person_id
DROP FUNCTION IF EXISTS get_person_emails(integer) CASCADE;
CREATE FUNCTION get_person_emails(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM
		(SELECT * FROM peeps.emails_full_view WHERE person_id = $1 ORDER BY id) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- POST /people/:id/merge?id=old_id
-- PARAMS: person_id to KEEP, person_id to CHANGE
DROP FUNCTION IF EXISTS merge_person(integer, integer) CASCADE;
CREATE FUNCTION merge_person(integer, integer, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM person_merge_from_to($2, $1);
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.person_view WHERE id = $1) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /people/unmailed
-- PARAMS: -none-
DROP FUNCTION IF EXISTS people_unemailed() CASCADE;
CREATE FUNCTION people_unemailed(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.people_view
		WHERE email_count = 0 ORDER BY id DESC LIMIT 200) r;
END;
$$ LANGUAGE plpgsql;


-- GET /search?q=term
-- PARAMS: search term
DROP FUNCTION IF EXISTS people_search(text) CASCADE;
CREATE FUNCTION people_search(text, OUT mime text, OUT js json) AS $$
DECLARE
	q text;
m4_ERRVARS
BEGIN
	q := concat('%', btrim($1, E'\t\r\n '), '%');
	IF LENGTH(q) < 4 THEN
		RAISE 'search term too short';
	END IF;
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM
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
DROP FUNCTION IF EXISTS get_stat(integer) CASCADE;
CREATE FUNCTION get_stat(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.stats_view WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;



-- PUT /stat/:id
-- PARAMS: stats.id, json
DROP FUNCTION IF EXISTS update_stat(integer, json) CASCADE;
CREATE FUNCTION update_stat(integer, json, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM public.jsonupdate('peeps.userstats', $1, $2,
		public.cols2update('peeps', 'userstats', ARRAY['id', 'created_at']));
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.stats_view WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /stats/:id
-- PARAMS: stats.id
DROP FUNCTION IF EXISTS delete_stat(integer) CASCADE;
CREATE FUNCTION delete_stat(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.stats_view WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	ELSE
		DELETE FROM peeps.userstats WHERE id = $1;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /urls/:id
-- PARAMS: urls.id
DROP FUNCTION IF EXISTS get_url(integer) CASCADE;
CREATE FUNCTION get_url(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.urls WHERE id=$1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- DELETE /urls/:id
-- PARAMS: urls.id
DROP FUNCTION IF EXISTS delete_url(integer) CASCADE;
CREATE FUNCTION delete_url(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.urls WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	ELSE
		DELETE FROM peeps.urls WHERE id = $1;
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /urls/:id
-- PARAMS: urls.id, JSON with allowed: person_id::int, url::text, main::boolean
DROP FUNCTION IF EXISTS update_url(integer, json) CASCADE;
CREATE FUNCTION update_url(integer, json, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM public.jsonupdate('peeps.urls', $1, $2,
		public.cols2update('peeps', 'urls', ARRAY['id']));
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM (SELECT * FROM peeps.urls WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /formletters
-- PARAMS: -none-
DROP FUNCTION IF EXISTS get_formletters() CASCADE;
CREATE FUNCTION get_formletters(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM
		(SELECT * FROM peeps.formletters_view ORDER BY title) r;
END;
$$ LANGUAGE plpgsql;


-- POST /formletters
-- PARAMS: title
DROP FUNCTION IF EXISTS create_formletter(text) CASCADE;
CREATE FUNCTION create_formletter(text, OUT mime text, OUT js json) AS $$
DECLARE
	new_id integer;
m4_ERRVARS
BEGIN
	INSERT INTO formletters(title) VALUES ($1) RETURNING id INTO new_id;
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM
		(SELECT * FROM peeps.formletter_view WHERE id = new_id) r;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- GET /formletters/:id
-- PARAMS: formletters.id
DROP FUNCTION IF EXISTS get_formletter(integer) CASCADE;
CREATE FUNCTION get_formletter(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM
		(SELECT * FROM peeps.formletter_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- PUT /formletters/:id
-- PARAMS: formletters.id, JSON keys: title, explanation, body
DROP FUNCTION IF EXISTS update_formletter(integer, json) CASCADE;
CREATE FUNCTION update_formletter(integer, json, OUT mime text, OUT js json) AS $$
DECLARE
m4_ERRVARS
BEGIN
	PERFORM public.jsonupdate('peeps.formletters', $1, $2,
		public.cols2update('peeps', 'formletters', ARRAY['id', 'created_at']));
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM
		(SELECT * FROM peeps.formletter_view WHERE id = $1) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
m4_ERRCATCH
END;
$$ LANGUAGE plpgsql;


-- DELETE /formletters/:id
-- PARAMS: formletters.id
DROP FUNCTION IF EXISTS delete_formletter(integer) CASCADE;
CREATE FUNCTION delete_formletter(integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT row_to_json(r) INTO js FROM
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
DROP FUNCTION IF EXISTS parsed_formletter(integer, integer) CASCADE;
CREATE FUNCTION parsed_formletter(integer, integer, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	js := json_build_object('body', parse_formletter_body($1, $2));
END;
$$ LANGUAGE plpgsql;


-- GET /locations
-- PARAMS: -none-
DROP FUNCTION IF EXISTS all_countries() CASCADE;
CREATE FUNCTION all_countries(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.countries ORDER BY name) r;
END;
$$ LANGUAGE plpgsql;


-- GET /countries
-- PARAMS: -none-
DROP FUNCTION IF EXISTS country_count() CASCADE;
CREATE FUNCTION country_count(OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT country, COUNT(*) FROM peeps.people
		WHERE country IS NOT NULL GROUP BY country ORDER BY COUNT(*) DESC, country) r;
END;
$$ LANGUAGE plpgsql;


-- GET /states/:country_code
-- PARAMS: 2-letter country code
DROP FUNCTION IF EXISTS state_count(char(2)) CASCADE;
CREATE FUNCTION state_count(char(2), OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT state, COUNT(*) FROM peeps.people
		WHERE country = $1 AND state IS NOT NULL AND state != ''
		GROUP BY state ORDER BY COUNT(*) DESC, state) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /cities/:country_code/:state
-- PARAMS: 2-letter country code, state name
DROP FUNCTION IF EXISTS city_count(char(2)) CASCADE;
CREATE FUNCTION city_count(char(2), text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT city, COUNT(*) FROM peeps.people
		WHERE country=$1 AND state=$2 AND (city IS NOT NULL AND city != '')
		GROUP BY city ORDER BY COUNT(*) DESC, city) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /cities/:country_code
-- PARAMS: 2-letter country code
DROP FUNCTION IF EXISTS city_count(char(2)) CASCADE;
CREATE FUNCTION city_count(char(2), OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT city, COUNT(*) FROM peeps.people
		WHERE country=$1 AND (city IS NOT NULL AND city != '')
		GROUP BY city ORDER BY COUNT(*) DESC, city) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code
-- PARAMS: 2-letter country code
DROP FUNCTION IF EXISTS people_from_country(char(2)) CASCADE;
CREATE FUNCTION people_from_country(char(2), OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code?state=XX
-- PARAMS: 2-letter country code, state
DROP FUNCTION IF EXISTS people_from_state(char(2)) CASCADE;
CREATE FUNCTION people_from_state(char(2), text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1 AND state=$2)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code?city=XX
-- PARAMS: 2-letter country code, state
DROP FUNCTION IF EXISTS people_from_city(char(2)) CASCADE;
CREATE FUNCTION people_from_city(char(2), text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1 AND city=$2)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /where/:country_code?city=XX&state=XX
-- PARAMS: 2-letter country code, state, city
DROP FUNCTION IF EXISTS people_from_state_city(char(2)) CASCADE;
CREATE FUNCTION people_from_state_city(char(2), text, text, OUT mime text, OUT js json) AS $$
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.people_view WHERE id IN
		(SELECT id FROM peeps.people WHERE country=$1 AND state=$2 AND city=$3)
		ORDER BY email_count DESC, name) r;
	IF js IS NULL THEN
m4_NOTFOUND
	END IF;
END;
$$ LANGUAGE plpgsql;



-- GET /stats/:key/:value
-- PARAMS: stats.name, stats.value
DROP FUNCTION IF EXISTS get_stats(text, text) CASCADE;
CREATE FUNCTION get_stats(text, text, OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.stats_view
		WHERE name = $1 AND value = $2) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /stats/:key
-- PARAMS: stats.name
DROP FUNCTION IF EXISTS get_stats(text) CASCADE;
CREATE FUNCTION get_stats(text, OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT * FROM peeps.stats_view WHERE name = $1) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /statcount/:key
-- PARAMS: stats.name
DROP FUNCTION IF EXISTS get_stat_value_count(text) CASCADE;
CREATE FUNCTION get_stat_value_count(text, OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT statvalue AS value, COUNT(*) AS count
		FROM peeps.userstats WHERE statkey=$1 GROUP BY statvalue ORDER BY statvalue) r;
	IF js IS NULL THEN
		js := '[]';
	END IF;
END;
$$ LANGUAGE plpgsql;


-- GET /statcount
-- PARAMS: -none-
DROP FUNCTION IF EXISTS get_stat_name_count() CASCADE;
CREATE FUNCTION get_stat_name_count(OUT mime text, OUT js json) AS $$
DECLARE
BEGIN
	mime := 'application/json';
	SELECT json_agg(r) INTO js FROM (SELECT statkey AS name, COUNT(*) AS count
		FROM peeps.userstats GROUP BY statkey ORDER BY statkey) r;
END;
$$ LANGUAGE plpgsql;


