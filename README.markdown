Welcome
=======

sql2mql is a simple tool for converting SQL syntax into MongoDB commands. It is written in pure
CoffeeScript and is extremely easy to use:

    $ coffee sql2mql "SELECT * FROM users WHERE age=33"
    db.users.find({"age":33})

*This tool is not meant to be used as a runtime language converter, but as an educational (or time*
*saving) utility.*

Examples
========

    $ coffee sql2mql "SELECT * FROM users WHERE age>33 AND age<=40"
    db.users.find({"age":{$gt:33,$lte:40}})
-
    $ coffee sql2mql "SELECT * FROM users WHERE age=33 ORDER BY name"
    db.users.find({"age":33}).sort({name:1})
-
    $ coffee sql2mql 'SELECT * FROM users WHERE name LIKE "Joe%"'
    db.users.find({"name":/^Joe/})
-
    $ coffee sql2mql 'UPDATE users SET a=a+2 WHERE b="q"'
    db.users.update({"b":"q"}, {$inc:{"a":2}}, false, true)
-
    $ coffee sql2mql 'DELETE FROM users WHERE z="abc"'
    db.users.remove({"z":"abc"})
-
    $ coffee sql2mql "CREATE TABLE mycoll (a Number, b Number)"
    db.createCollection("mycoll")
