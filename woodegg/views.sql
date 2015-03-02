----------------------------------------
--------------- VIEWS FOR JSON RESPONSES:
----------------------------------------

DROP VIEW IF EXISTS researcher_view CASCADE;
CREATE VIEW researcher_view AS
	SELECT researchers.id, peeps.people.name, researchers.bio
		FROM woodegg.researchers, peeps.people
		WHERE researchers.person_id=peeps.people.id;

DROP VIEW IF EXISTS writer_view CASCADE;
CREATE VIEW writer_view AS
	SELECT writers.id, peeps.people.name, writers.bio
		FROM woodegg.writers, peeps.people
		WHERE writers.person_id=peeps.people.id;

DROP VIEW IF EXISTS editor_view CASCADE;
CREATE VIEW editor_view AS
	SELECT editors.id, peeps.people.name, editors.bio
		FROM woodegg.editors, peeps.people
		WHERE editors.person_id=peeps.people.id;

