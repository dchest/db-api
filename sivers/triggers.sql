CREATE FUNCTION clean_comments_fields() RETURNS TRIGGER AS $$
BEGIN
	NEW.uri = regexp_replace(lower(NEW.uri), '[^a-z0-9-]', '', 'g');
	NEW.name = btrim(regexp_replace(NEW.name, '[\r\n\t]', ' ', 'g'));
	NEW.email = btrim(lower(NEW.email));
	NEW.html = replace(public.escape_html(public.strip_tags(btrim(NEW.html))),
			':-)',
			'<img src="/images/icon_smile.gif" width="15" height="15" alt="smile">');
	IF TG_OP = 'INSERT' AND NEW.person_id IS NULL THEN
		SELECT id INTO NEW.person_id FROM peeps.person_create(NEW.name, NEW.email);
	END IF;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_comments_fields BEFORE INSERT OR UPDATE OF uri, name, email ON sivers.comments FOR EACH ROW EXECUTE PROCEDURE clean_comments_fields();

