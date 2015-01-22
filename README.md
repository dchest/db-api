# db-api

My PostgreSQL database.

In each schema subdirectory:

`m4 schema.m4 > schema.sql`

And when I change fixtures:

`sh fixtures.sh`

© 2015 50pop LLC | Contact: [Derek Sivers](http://sivers.org/)

# TODO:

Can a view be generated from an already-selected record, stored in a variable?  If so, the approach of one function looking up just the ids, then passing id to the view to re-select it could be replaced with that approach.  And after doing an update of a status like opened/closed, could do RETURNING * to return its values instead of selecting again.

