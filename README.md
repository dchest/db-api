# db-api

My PostgreSQL database.

In each schema subdirectory:

`m4 schema.m4 > schema.sql`

And when I change fixtures:

`sh fixtures.sh`

© 2015 50pop LLC | Contact: [Derek Sivers](http://sivers.org/)

# WHAT'S WHAT:

Just a reminder to my future self, what's with this new PostgreSQL db-api way of doing things

### What's gone:

**d50b** was just Ruby+Sequel models around the database.  No more.  All gone.

**50apis** is now routes in db-api/HTTP since they use schema.sql files for resetting fixtures.  Views are now SQL views in db-api/~/views.sql

### What's new:

**db-api** has subdirectories with the rules that were once in d50b models, and views that were once in 50apis/views

**db-api/HTTP** has Sinatra API routes

### What's mostly the same:

**a50c** is still a “client library” Ruby gem to access the HTTP API with Ruby.  Only now instead of Struct with method calls, it's Hash with symbol keys.

I'll probably have to make other “client libraries” some day: JavaScript for JS-heavy front-end sites, Java for Android, ObjC for iOS?


# TODO:

Can a view be generated from an already-selected record, stored in a variable?  If so, the approach of one function looking up just the ids, then passing id to the view to re-select it could be replaced with that approach.  And after doing an update of a status like opened/closed, could do RETURNING * to return its values instead of selecting again.

