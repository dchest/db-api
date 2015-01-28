CREATE FUNCTION clean_comments_fields() RETURNS TRIGGER AS $$
BEGIN
	NEW.uri = regexp_replace(lower(NEW.uri), '[^a-z0-9-]', '', 'g');
	NEW.name = trim(regexp_replace(NEW.name, '[\r\n\t]', ' ', 'g'));
	NEW.email = trim(lower(NEW.email));
	IF TG_OP = 'INSERT' AND NEW.person_id IS NULL THEN
		SELECT id INTO NEW.person_id FROM peeps.person_create(NEW.name, NEW.email);
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_comments_fields BEFORE INSERT OR UPDATE OF uri, name, email ON sivers.comments FOR EACH ROW EXECUTE PROCEDURE clean_comments_fields();

