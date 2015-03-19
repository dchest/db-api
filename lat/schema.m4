changequote(«, »)dnl
define(«m4_NOTFOUND», «
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'about:blank',
		'title', 'Not Found',
		'status', 404);
»)dnl
define(«m4_ERRVARS», «
	err_code text;
	err_msg text;
	err_detail text;
	err_context text;
»)dnl
define(«m4_ERRCATCH», «
EXCEPTION
	WHEN OTHERS THEN GET STACKED DIAGNOSTICS
		err_code = RETURNED_SQLSTATE,
		err_msg = MESSAGE_TEXT,
		err_detail = PG_EXCEPTION_DETAIL,
		err_context = PG_EXCEPTION_CONTEXT;
	mime := 'application/problem+json';
	js := json_build_object(
		'type', 'http://www.postgresql.org/docs/9.4/static/errcodes-appendix.html#' || err_code,
		'title', err_msg,
		'detail', err_detail || err_context);
»)dnl
include(«tables.sql»)dnl
include(«triggers.sql»)dnl
include(«functions.sql»)dnl
include(«views.sql»)dnl
include(«api.sql»)dnl

