----------------------------
------------------ TRIGGERS:
----------------------------

-- strip all line breaks, tabs, and spaces around concept before storing
CREATE OR REPLACE FUNCTION clean_concept() RETURNS TRIGGER AS $$
BEGIN
	NEW.concept = btrim(regexp_replace(NEW.concept, '\s+', ' ', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_concept ON lat.concepts CASCADE;
CREATE TRIGGER clean_concept BEFORE INSERT OR UPDATE OF concept ON lat.concepts FOR EACH ROW EXECUTE PROCEDURE clean_concept();


-- lowercase and strip all line breaks, tabs, and spaces around tag before storing
CREATE OR REPLACE FUNCTION clean_tag() RETURNS TRIGGER AS $$
BEGIN
	NEW.tag = lower(btrim(regexp_replace(NEW.tag, '\s+', ' ', 'g')));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS clean_tag ON lat.tags CASCADE;
CREATE TRIGGER clean_tag BEFORE INSERT OR UPDATE OF tag ON lat.tags FOR EACH ROW EXECUTE PROCEDURE clean_tag();

