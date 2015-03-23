----------------------------
------------------ TRIGGERS:
----------------------------

-- strip all line breaks, tabs, and spaces around title and concept before storing
CREATE OR REPLACE FUNCTION clean_concept() RETURNS TRIGGER AS $$
BEGIN
	NEW.title = btrim(regexp_replace(NEW.title, '\s+', ' ', 'g'));
	NEW.concept = btrim(regexp_replace(NEW.concept, '\s+', ' ', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_concept ON lat.concepts CASCADE;
CREATE TRIGGER clean_concept BEFORE INSERT OR UPDATE ON lat.concepts
	FOR EACH ROW EXECUTE PROCEDURE lat.clean_concept();


-- strip all line breaks, tabs, and spaces around url before storing (& validating)
CREATE OR REPLACE FUNCTION clean_url() RETURNS TRIGGER AS $$
BEGIN
	NEW.url = regexp_replace(NEW.url, '\s', '', 'g');
	NEW.notes = btrim(regexp_replace(NEW.notes, '\s+', ' ', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_url ON lat.urls CASCADE;
CREATE TRIGGER clean_url BEFORE INSERT OR UPDATE ON lat.urls
	FOR EACH ROW EXECUTE PROCEDURE lat.clean_url();


-- lowercase and strip all line breaks, tabs, and spaces around tag before storing
CREATE OR REPLACE FUNCTION clean_tag() RETURNS TRIGGER AS $$
BEGIN
	NEW.tag = lower(btrim(regexp_replace(NEW.tag, '\s+', ' ', 'g')));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_tag ON lat.tags CASCADE;
CREATE TRIGGER clean_tag BEFORE INSERT OR UPDATE OF tag ON lat.tags
	FOR EACH ROW EXECUTE PROCEDURE lat.clean_tag();


-- strip all line breaks, tabs, and spaces around thought before storing
CREATE OR REPLACE FUNCTION clean_pairing() RETURNS TRIGGER AS $$
BEGIN
	NEW.thoughts = btrim(regexp_replace(NEW.thoughts, '\s+', ' ', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_pairing ON lat.pairings CASCADE;
CREATE TRIGGER clean_pairing BEFORE INSERT OR UPDATE OF thoughts ON lat.pairings
	FOR EACH ROW EXECUTE PROCEDURE lat.clean_pairing();

