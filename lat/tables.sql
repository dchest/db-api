SET client_min_messages TO ERROR;
DROP SCHEMA IF EXISTS lat CASCADE;
BEGIN;

CREATE SCHEMA lat;
SET search_path = lat;

CREATE TABLE concepts (
	id serial primary key,
	title varchar(127),
	concept text,
	created_at date not null default CURRENT_DATE
);

CREATE TABLE urls (
	id serial primary key,
	url text CONSTRAINT url_format CHECK (url ~ '^https?://[0-9a-zA-Z_-]+\.[a-zA-Z0-9]+'),
	notes text
);

CREATE TABLE tags (
	id serial primary key,
	tag varchar(32) unique not null CONSTRAINT emptytag CHECK (length(tag) > 0)
);

CREATE TABLE concepts_urls (
	concept_id integer not null references concepts(id) on delete cascade,
	url_id integer not null references urls(id) on delete cascade,
	primary key (concept_id, url_id)
);

CREATE TABLE concepts_tags (
	concept_id integer not null references concepts(id) on delete cascade,
	tag_id integer not null references tags(id) on delete cascade
	primary key (concept_id, tag_id)
);

CREATE TABLE pairings (
	id serial primary key,
	created_at date not null default CURRENT_DATE,
	concept1_id integer not null references concepts(id) on delete cascade,
	concept2_id integer not null references concepts(id) on delete cascade,
	CHECK(concept1_id != concept2_id),
	UNIQUE(concept1_id, concept2_id),
	thoughts text
);

COMMIT;

