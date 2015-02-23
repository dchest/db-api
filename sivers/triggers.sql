CREATE FUNCTION comments_changed() RETURNS TRIGGER AS $$
DECLARE
	u text;
BEGIN
	IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
		u := NEW.uri;
	ELSE
		u := OLD.uri;
	END IF;
	PERFORM pg_notify('comments_changed', u);
	RETURN OLD;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER comments_changed AFTER INSERT OR UPDATE OR DELETE ON comments FOR EACH ROW EXECUTE PROCEDURE comments_changed();

