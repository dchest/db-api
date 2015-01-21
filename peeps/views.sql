CREATE VIEW emails_view AS
	SELECT id, subject, created_at, their_name, their_email FROM emails;

CREATE VIEW email_view AS
	SELECT id, person_id, profile, category,
		created_at, (SELECT row_to_json(cb) AS creator FROM
			(SELECT emailers.id, people.name FROM emailers
				JOIN people ON emailers.person_id=people.id
				WHERE emailers.id = created_by) cb),
		opened_at, (SELECT row_to_json(ob) AS openor FROM
			(SELECT emailers.id, people.name FROM emailers
				JOIN people ON emailers.person_id=people.id
				WHERE emailers.id = opened_by) ob),
		closed_at, (SELECT row_to_json(lb) AS closor FROM
			(SELECT emailers.id, people.name FROM emailers
				JOIN people ON emailers.person_id=people.id
				WHERE emailers.id = closed_by) lb),
		message_id, outgoing, their_email, their_name, headers, subject, body,
		(SELECT json_agg(atch) AS attachments FROM
			(SELECT id, filename FROM email_attachments
				WHERE email_id=emails.id) atch)
		FROM emails;

