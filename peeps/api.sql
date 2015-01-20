-- API REQUIRES AUTHENTICATION. User must be in peeps.emailers
-- peeps.emailers.id needed as first argument to many functions here

-- PARAMS: emailer_id
CREATE FUNCTION get_profiles(integer, OUT mime text, OUT js text) AS $$
BEGIN
	mime := 'application/json';
	SELECT array_to_json(array(SELECT * FROM emailer_profiles($1))) INTO js;
END;
$$ LANGUAGE plpgsql;


