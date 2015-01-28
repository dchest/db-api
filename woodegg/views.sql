-- SELECT * FROM researcher_person WHERE id = 3;
CREATE VIEW researcher_person AS SELECT x.*,
	p.name, p.email, p.address, p.city, p.state, p.country
	FROM researchers x
	JOIN peeps.people p ON x.person_id=p.id;


-- SELECT * FROM writer_person WHERE id = 3;
CREATE VIEW writer_person AS SELECT x.*,
	p.name, p.email, p.address, p.city, p.state, p.country
	FROM writers x
	JOIN peeps.people p ON x.person_id=p.id;


-- SELECT * FROM customer_person WHERE id = 3;
CREATE VIEW customer_person AS SELECT x.*,
	p.name, p.email, p.address, p.city, p.state, p.country
	FROM customers x
	JOIN peeps.people p ON x.person_id=p.id;


-- SELECT * FROM editor_person WHERE id = 3;
CREATE VIEW editor_person AS SELECT x.*,
	p.name, p.email, p.address, p.city, p.state, p.country
	FROM editors x
	JOIN peeps.people p ON x.person_id=p.id;
