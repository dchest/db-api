----------------------------
----------------- FUNCTIONS:
----------------------------

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

