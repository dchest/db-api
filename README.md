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

**a50c** is still a “client library” Ruby gem to access the HTTP API with Ruby.  Only now instead of Struct with method calls, it's Hash with symbol keys.  I'll probably have to make other “client libraries” some day: JavaScript for JS-heavy front-end sites, Java for Android, ObjC for iOS?

**50web** is still all the end-user websites, using Sinatra + a50c gem.  Only now instead of Struct with method calls, it's Hash with symbol keys.

### Authentication:

**db-api/HTTP** REST API uses HTTP Basic Authentication, and most **a50c** client library classes need the API key and pass to initialize.  When testing API, just give it the key and pass strings from the fixtures.

To see whether they're legit, PostgreSQL searches api_keys table for that key, pass, and making sure this API is in the array of apis.  This could be a peeps schema function, but for now is not.  It'd probably be two queries: one for api_keys to get the person, then once authed, returning person_id, another one could get peeps.emailers.id or muckwork.managers.id or whatever, based on their person_id.  One more layer where it might fail just in case their person_id is not in that table.

When **real people** using it, a **50web** route called **ModAuth** checks for three cookies:  person_id, api_key, api_pass.  If they don't exist, it redirects to /login

/login is a form requiring email address and password, posted to /login, which is also grabbed by ModAuth.  If peeps.person authenticates that email & password, it looks in api_keys for theirs, and returns api_keys using SELECT * FROM auth_api(akey, apass, APIName)

If POST /login works, it sets the 3 needed cookies (person_id, api_key, api_pass).  Those are included in all calls, and sent to A50C To init client library.


# HTTP ports:

* 10000 = Peep
* 10001 = Peep test
* 10010 = MusicThoughtsPublic
* 10011 = MusicThoughtsPublic test
* 10020 = SiversCommentsAdmin
* 10021 = SiversCommentsAdmin test
* 10030 = WoodEgg
* 10031 = WoodEgg test


# TODO:

* Can a view be generated from an already-selected record, stored in a variable?  If so, the approach of one function looking up just the ids, then passing id to the view to re-select it could be replaced with that approach.  And after doing an update of a status like opened/closed, could do RETURNING * to return its values instead of selecting again.

