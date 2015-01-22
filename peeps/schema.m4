changequote(«, »)dnl
define(«m4_NOTFOUND», «
		mime := 'application/problem+json';
		js := '{"type": "about:blank", "title": "Not Found", "status": 404}';
»)dnl
include(«tables.sql»)dnl
include(«views.sql»)dnl
include(«functions.sql»)dnl
include(«triggers.sql»)dnl
include(«api.sql»)dnl

