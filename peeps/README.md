# TODO:

## Protected file downloads

Use people.lopass for person authentication.

```sql
CREATE TABLE files (
	id serial primary key,
	filename varchar(127) unique,
	mime varchar(32),
	bytes integer
);

CREATE TABLE file_permissions (
	file_id integer not null references files(id),
	person_id integer not null references people(id),
	PRIMARY KEY (file_id, person_id)
);

CREATE TABLE file_history (
	id serial primary key,
	created_at datetime,
	file_id integer not null references files(id),
	person_id integer not null references people(id),
	client_data text
);
```

### Example URL & SQL:

<https://sivers.org/download/321321/abcd/5/DerekSivers-MarketingYourMusic.pdf>

```sql
	SELECT files.* FROM files
	JOIN file_permissions fp ON files.id=fp.file_id
	JOIN people ON fp.person_id=people.id
	WHERE fp.file_id=5 AND fp.person_id=321321 AND people.lopass='abcd';
```

### API:

	-- PARAMS: person_id, file_id, lopass, client_data
	download_file(integer, integer, text, text)
	Returns JSON of files.* info and logs download

### Rack::Sendfile ?

<http://www.rubydoc.info/github/rack/rack/Rack/Sendfile>

