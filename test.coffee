require('coffee-script')
vows = require('vows')
assert = require('assert')
sql2mql = require('./sql2mql.coffee')
mql = new (sql2mql.Mql)

# this is the list of tests with the expected outcomes
tests =
	# nothing fancy
	'SELECT * FROM mytable': 'db.mytable.find()'
	'SELECT * FROM users LIMIT 1': 'db.users.findOne()'
	
	# fields
	'SELECT a,b FROM users': 'db.users.find({}, {a:1,b:1})'
	'SELECT a,b FROM users WHERE age=33': 'db.users.find({"age":33}, {a:1,b:1})'
	
	# WHERE operators
	'SELECT * FROM users WHERE age!=33': 'db.users.find({"age":{$ne:33}})'
	'SELECT * FROM users WHERE age<=33': 'db.users.find({"age":{$lte:33}})'
	'SELECT * FROM users WHERE age=33': 'db.users.find({"age":33})'
	'SELECT * FROM users WHERE age>33': 'db.users.find({"age":{$gt:33}})'
	'SELECT * FROM users WHERE age<33': 'db.users.find({"age":{$lt:33}})'
	'SELECT * FROM users WHERE age>=33': 'db.users.find({"age":{$gte:33}})'
	
	# WHERE logic
	"SELECT * FROM users WHERE a=1 OR b=2": 'db.users.find({$or:[{"a":1},{"b":2}]})'
	"SELECT * FROM users WHERE a=1 AND b='q'": "db.users.find({\"a\":1,\"b\":'q'})"
	'SELECT * FROM users WHERE age>33 AND age<=40': 'db.users.find({"age":{$gt:33,$lte:40}})'
	
	# ORDER BY
	'SELECT * FROM users ORDER BY name DESC': 'db.users.find().sort({name:-1})'
	'SELECT * FROM users WHERE age=33 ORDER BY name': 'db.users.find({"age":33}).sort({name:1})'
	
	# LIMIT
	"SELECT * FROM users LIMIT 10 SKIP 20": "db.users.find().limit(10).skip(20)"
	"SELECT * FROM users SKIP 20": "db.users.find().skip(20)"
	"SELECT * FROM users LIMIT 10": "db.users.find().limit(10)"
	
	# LIKE
	'SELECT * FROM users WHERE name LIKE "Joe"': 'db.users.find({"name":/^Joe$/})'
	'SELECT * FROM users WHERE name LIKE "%Joe"': 'db.users.find({"name":/Joe$/})'
	'SELECT * FROM users WHERE name LIKE "Joe%"': 'db.users.find({"name":/^Joe/})'
	'SELECT * FROM users WHERE name LIKE "%Joe%"': 'db.users.find({"name":/Joe/})'
	
	# DELETE
	'DELETE FROM users WHERE z="abc"': 'db.users.remove({"z":"abc"})'


# create batch
batch = {}
for k, v of tests
	do (k, v) ->
		batch[k] = {
			topic: => mql.processSql(k)
		}
		batch[k][v] = (topic) =>
			assert.equal(topic, v.toString())
	
# run
vows.describe('sql2mql tests').addBatch(batch).run()
