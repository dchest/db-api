-- Strip spaces and lowercase email address before validating & storing
CREATE OR REPLACE FUNCTION clean_email() RETURNS TRIGGER AS $$
BEGIN
	NEW.email = lower(regexp_replace(NEW.email, '\s', '', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_email ON peeps.people CASCADE;
CREATE TRIGGER clean_email BEFORE INSERT OR UPDATE OF email ON peeps.people FOR EACH ROW EXECUTE PROCEDURE clean_email();


CREATE OR REPLACE FUNCTION clean_their_email() RETURNS TRIGGER AS $$
BEGIN
	NEW.their_name = peeps.strip_tags(btrim(regexp_replace(NEW.their_name, '\s+', ' ', 'g')));
	NEW.their_email = lower(regexp_replace(NEW.their_email, '\s', '', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_their_email ON peeps.people CASCADE;
CREATE TRIGGER clean_their_email BEFORE INSERT OR UPDATE OF their_name, their_email ON peeps.emails FOR EACH ROW EXECUTE PROCEDURE clean_their_email();


-- Strip all line breaks and spaces around name before storing
CREATE OR REPLACE FUNCTION clean_name() RETURNS TRIGGER AS $$
BEGIN
	NEW.name = peeps.strip_tags(btrim(regexp_replace(NEW.name, '\s+', ' ', 'g')));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_name ON peeps.people CASCADE;
CREATE TRIGGER clean_name BEFORE INSERT OR UPDATE OF name ON peeps.people FOR EACH ROW EXECUTE PROCEDURE clean_name();


-- Statkey has no whitespace at all. Statvalue trimmed but keeps inner whitespace.
CREATE OR REPLACE FUNCTION clean_userstats() RETURNS TRIGGER AS $$
BEGIN
	NEW.statkey = lower(regexp_replace(NEW.statkey, '[^[:alnum:]._-]', '', 'g'));
	IF NEW.statkey = '' THEN
		RAISE 'stats.key must not be empty';
	END IF;
	NEW.statvalue = btrim(NEW.statvalue, E'\r\n\t ');
	IF NEW.statvalue = '' THEN
		RAISE 'stats.value must not be empty';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_userstats ON peeps.userstats CASCADE;
CREATE TRIGGER clean_userstats BEFORE INSERT OR UPDATE OF statkey, statvalue ON peeps.userstats FOR EACH ROW EXECUTE PROCEDURE clean_userstats();


-- urls.url remove all whitespace, then add http:// if not there
CREATE OR REPLACE FUNCTION clean_url() RETURNS TRIGGER AS $$
BEGIN
	NEW.url = regexp_replace(NEW.url, '\s', '', 'g');
	IF NEW.url !~ '^https?://' THEN
		NEW.url = 'http://' || NEW.url;
	END IF;
	IF NEW.url !~ '^https?://[0-9a-zA-Z_-]+\.[a-zA-Z0-9]+' THEN
		RAISE 'bad url';
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_url ON peeps.urls CASCADE;
CREATE TRIGGER clean_url BEFORE INSERT OR UPDATE OF url ON peeps.urls FOR EACH ROW EXECUTE PROCEDURE clean_url();


-- Create "address" (first word of name) and random password upon insert of new person
CREATE OR REPLACE FUNCTION generated_person_fields() RETURNS TRIGGER AS $$
BEGIN
	NEW.address = split_part(btrim(regexp_replace(NEW.name, '\s+', ' ', 'g')), ' ', 1);
	NEW.lopass = random_string(4);
	NEW.newpass = unique_for_table_field(8, 'peeps.people', 'newpass');
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS generate_person_fields ON peeps.people CASCADE;
CREATE TRIGGER generate_person_fields BEFORE INSERT ON peeps.people FOR EACH ROW EXECUTE PROCEDURE generated_person_fields();


-- If something sets any of these fields to '', change it to NULL before saving
CREATE OR REPLACE FUNCTION null_person_fields() RETURNS TRIGGER AS $$
BEGIN
	IF btrim(NEW.country) = '' THEN
		NEW.country = NULL;
	END IF;
	IF btrim(NEW.email) = '' THEN
		NEW.email = NULL;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS null_person_fields ON peeps.people CASCADE;
CREATE TRIGGER null_person_fields BEFORE INSERT OR UPDATE OF country, email ON peeps.people FOR EACH ROW EXECUTE PROCEDURE null_person_fields();


-- No whitespace, all lowercase, for emails.profile and emails.category
CREATE OR REPLACE FUNCTION clean_emails_fields() RETURNS TRIGGER AS $$
BEGIN
	NEW.profile = regexp_replace(lower(NEW.profile), '[^[:alnum:]_@-]', '', 'g');
	IF TG_OP = 'INSERT' AND (NEW.category IS NULL OR trim(both ' ' from NEW.category) = '') THEN
		NEW.category = NEW.profile;
	ELSE
		NEW.category = regexp_replace(lower(NEW.category), '[^[:alnum:]_@-]', '', 'g');
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_emails_fields ON peeps.emails CASCADE;
CREATE TRIGGER clean_emails_fields BEFORE INSERT OR UPDATE OF profile, category ON peeps.emails FOR EACH ROW EXECUTE PROCEDURE clean_emails_fields();


-- Update people.email_count when number of emails for this person_id changes
CREATE OR REPLACE FUNCTION update_email_count() RETURNS TRIGGER AS $$
DECLARE
	pid integer := NULL;
BEGIN
	IF ((TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.person_id IS NOT NULL) THEN
		pid := NEW.person_id;
	ELSIF (TG_OP = 'UPDATE' AND OLD.person_id IS NOT NULL) THEN
		pid := OLD.person_id;  -- in case updating to set person_id = NULL, recalcuate old one
	ELSIF (TG_OP = 'DELETE' AND OLD.person_id IS NOT NULL) THEN
		pid := OLD.person_id;
	END IF;
	IF pid IS NOT NULL THEN
		UPDATE peeps.people SET email_count=(SELECT COUNT(*) FROM peeps.emails WHERE person_id = pid) WHERE id = pid;
	END IF;
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS update_email_count ON peeps.emails CASCADE;
CREATE TRIGGER update_email_count AFTER INSERT OR DELETE OR UPDATE OF person_id ON peeps.emails FOR EACH ROW EXECUTE PROCEDURE update_email_count();


-- Setting a URL to be the "main" one sets all other URLs for that person to be NOT main
CREATE OR REPLACE FUNCTION one_main_url() RETURNS TRIGGER AS $$
BEGIN
	IF NEW.main = 't' THEN
		UPDATE peeps.urls SET main=FALSE WHERE person_id=NEW.person_id AND id != NEW.id;
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS one_main_url ON peeps.urls CASCADE;
CREATE TRIGGER one_main_url AFTER INSERT OR UPDATE OF main ON peeps.urls FOR EACH ROW EXECUTE PROCEDURE one_main_url();


-- Generate random strings when creating new api_key
CREATE OR REPLACE FUNCTION generated_api_keys() RETURNS TRIGGER AS $$
BEGIN
	NEW.akey = unique_for_table_field(8, 'peeps.api_keys', 'akey');
	NEW.apass = random_string(8);
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS generated_api_keys ON peeps.api_keys CASCADE;
CREATE TRIGGER generated_api_keys BEFORE INSERT ON peeps.api_keys FOR EACH ROW EXECUTE PROCEDURE generated_api_keys();


-- generate message_id for outgoing emails
CREATE OR REPLACE FUNCTION make_message_id() RETURNS TRIGGER AS $$
BEGIN
	IF NEW.message_id IS NULL AND (NEW.outgoing IS TRUE OR NEW.outgoing IS NULL) THEN
		NEW.message_id = CONCAT(
			to_char(current_timestamp, 'YYYYMMDDHH24MISSMS'),
			'.', NEW.person_id, '@sivers.org');
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS make_message_id ON peeps.emails CASCADE;
CREATE TRIGGER make_message_id BEFORE INSERT ON peeps.emails FOR EACH ROW EXECUTE PROCEDURE make_message_id();

