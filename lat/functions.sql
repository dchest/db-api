-- strip all line breaks, tabs, and spaces around concept before storing
CREATE FUNCTION clean_concept() RETURNS TRIGGER AS $$
BEGIN
	NEW.concept = btrim(regexp_replace(NEW.concept, '\s+', ' ', 'g'));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_concept BEFORE INSERT OR UPDATE OF concept ON concepts FOR EACH ROW EXECUTE PROCEDURE clean_concept();

-- lowercase and strip all line breaks, tabs, and spaces around tag before storing
CREATE FUNCTION clean_tag() RETURNS TRIGGER AS $$
BEGIN
	NEW.tag = lower(btrim(regexp_replace(NEW.tag, '\s+', ' ', 'g')));
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER clean_tag BEFORE INSERT OR UPDATE OF tag ON tags FOR EACH ROW EXECUTE PROCEDURE clean_tag();

-- create pairing of two concepts that haven't been paired before
CREATE FUNCTION new_pairing() RETURNS SETOF pairings AS $$
DECLARE
	id1 integer;
	id2 integer;
BEGIN
	SELECT c1.id, c2.id INTO id1, id2
		FROM concepts c1 CROSS JOIN concepts c2
		LEFT JOIN pairings p ON (
			(c1.id=p.concept1_id AND c2.id=p.concept2_id) OR
			(c1.id=p.concept2_id AND c2.id=p.concept1_id)
		) WHERE c1.id != c2.id AND p.id IS NULL ORDER BY RANDOM();
	IF id1 IS NULL THEN
		RAISE EXCEPTION 'no unpaired concepts';
	END IF;
	RETURN QUERY INSERT INTO pairings (concept1_id, concept2_id)
		VALUES (id1, id2) RETURNING *;
END;
$$ LANGUAGE plpgsql;

