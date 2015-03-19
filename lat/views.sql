----------------------------------------
--------------- VIEWS FOR JSON RESPONSES:
----------------------------------------

DROP VIEW IF EXISTS concept_view CASCADE;
CREATE VIEW concept_view AS
	SELECT id, created_at, title, concept, (SELECT json_agg(uq) AS urls FROM
		(SELECT u.* FROM lat.urls u, lat.concepts_urls cu
			WHERE u.id=cu.url_id AND cu.concept_id=lat.concepts.id) uq),
	(SELECT json_agg(tq) AS tags FROM
		(SELECT t.* FROM lat.tags t, lat.concepts_tags ct
			WHERE t.id=ct.tag_id AND ct.concept_id=concepts.id) tq)
	FROM lat.concepts;

DROP VIEW IF EXISTS pairing_view CASCADE;
CREATE VIEW pairing_view AS
	SELECT id, created_at, thoughts,
		(SELECT row_to_json(c1) AS concept1 FROM
			(SELECT * FROM lat.concept_view WHERE id=lat.pairings.concept1_id) c1),
		(SELECT row_to_json(c2) AS concept2 FROM
			(SELECT * FROM lat.concept_view WHERE id=lat.pairings.concept2_id) c2)
	FROM lat.pairings;

