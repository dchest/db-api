changequote(«, »)dnl
define(«NOTFOUND», «
	IF js IS NULL THEN
		mime := 'application/problem+json';
		js := '{"type": "about:blank", "title": "Not Found", "status": 404}';
	END IF;
»)dnl
include(«tables.sql»)dnl
include(«views.sql»)dnl
include(«functions.sql»)dnl
include(«triggers.sql»)dnl
include(«api.sql»)dnl

