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
NOTFOUND
	ELSE
		UPDATE emails SET opened_at=NOW(), opened_by=$1 WHERE id = eid;
		mime := 'application/json';
		SELECT row_to_json(r) INTO js FROM (SELECT * FROM email_view WHERE id = eid) r;
	END IF;
END;
$$ LANGUAGE plpgsql;


