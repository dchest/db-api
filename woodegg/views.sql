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

DROP VIEW IF EXISTS answer_view CASCADE;
--CREATE VIEW answer_view AS

DROP VIEW IF EXISTS essay_view CASCADE;
--CREATE VIEW essay_view AS

DROP VIEW IF EXISTS book_view CASCADE;
-- {books.* + researchers[] writers[] editors[]}
--CREATE VIEW book_view AS

DROP VIEW IF EXISTS question_view CASCADE;
-- {template_id country topic subtopic question answers[] essays[]}
--CREATE VIEW question_view AS

DROP VIEW IF EXISTS country_view CASCADE;
-- {topics[{name subtopics[{name questions[{id question}]}]}] tidbits}
--CREATE VIEW country_view AS

DROP VIEW IF EXISTS templates_view CASCADE;
-- {topics[{id name subtopics[{name templates[{id template}]]]}
--CREATE VIEW templates_view AS

DROP VIEW IF EXISTS template_view CASCADE;
-- {topic subtopic template countries{code question answers[], essays[]}}
--CREATE VIEW template_view AS

DROP VIEW IF EXISTS topic_view CASCADE;
-- {subtopics[{name , templates {id }]}
--CREATE VIEW topic_view AS

DROP VIEW IF EXISTS subtopic_view CASCADE;
--CREATE VIEW subtopic_view AS
