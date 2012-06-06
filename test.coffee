require('coffee-script')
vows = require('vows')
assert = require('assert')
sql2mql = require('./sql2mql.coffee')
mql = new (sql2mql.Mql)

vows
	.describe('sql2mql tests')
	.addBatch
		'SELECT * FROM mytable':
			topic: -> mql.processSql('SELECT * FROM mytable')
		
			'db.mytable.find()': (topic) ->
				assert.equal(topic, 'db.mytable.find()')

		'SELECT a,b FROM users':
			topic: -> mql.processSql('SELECT a,b FROM users')
		
			'db.users.find({}, {a:1,b:1})': (topic) ->
				assert.equal(topic, 'db.users.find({}, {a:1,b:1})')

		'SELECT * FROM users WHERE age=33':
			topic: -> mql.processSql('SELECT * FROM users WHERE age=33')
		
			'db.users.find({"age":33})': (topic) ->
				assert.equal(topic, 'db.users.find({"age":33})')

		'SELECT a,b FROM users WHERE age=33':
			topic: -> mql.processSql('SELECT a,b FROM users WHERE age=33')
		
			'db.users.find({"age":33}, {a:1,b:1})': (topic) ->
				assert.equal(topic, 'db.users.find({"age":33}, {a:1,b:1})')

		'SELECT * FROM users WHERE age=33 ORDER BY name':
			topic: -> mql.processSql('SELECT * FROM users WHERE age=33 ORDER BY name')
		
			'db.users.find({"age":33}).sort({name:1})': (topic) ->
				assert.equal(topic, 'db.users.find({"age":33}).sort({name:1})')

		'SELECT * FROM users WHERE age>33':
			topic: -> mql.processSql('SELECT * FROM users WHERE age>33')
		
			'db.users.find({"age":{$gt:33}})': (topic) ->
				assert.equal(topic, 'db.users.find({"age":{$gt:33}})')

		'SELECT * FROM users WHERE age<33':
			topic: -> mql.processSql('SELECT * FROM users WHERE age<33')
		
			'db.users.find({"age":{$lt:33}})': (topic) ->
				assert.equal(topic, 'db.users.find({"age":{$lt:33}})')

		'SELECT * FROM users WHERE age>=33':
			topic: -> mql.processSql('SELECT * FROM users WHERE age>=33')
		
			'db.users.find({"age":{$gte:33}})': (topic) ->
				assert.equal(topic, 'db.users.find({"age":{$gte:33}})')

		'SELECT * FROM users WHERE age<=33':
			topic: -> mql.processSql('SELECT * FROM users WHERE age<=33')
		
			'db.users.find({"age":{$lte:33}})': (topic) ->
				assert.equal(topic, 'db.users.find({"age":{$lte:33}})')

		'SELECT * FROM users WHERE age!=33':
			topic: -> mql.processSql('SELECT * FROM users WHERE age!=33')
		
			'db.users.find({"age":{$lte:33}})': (topic) ->
				assert.equal(topic, 'db.users.find({"age":{$ne:33}})')

		'SELECT * FROM users WHERE name LIKE "%Joe%"':
			topic: -> mql.processSql('SELECT * FROM users WHERE name LIKE "%Joe%"')
		
			'db.users.find({"name":/Joe/})': (topic) ->
				assert.equal(topic, 'db.users.find({"name":/Joe/})')

		'SELECT * FROM users WHERE name LIKE "Joe%"':
			topic: -> mql.processSql('SELECT * FROM users WHERE name LIKE "Joe%"')
		
			'db.users.find({"name":/^Joe/})': (topic) ->
				assert.equal(topic, 'db.users.find({"name":/^Joe/})')

		'SELECT * FROM users WHERE name LIKE "%Joe"':
			topic: -> mql.processSql('SELECT * FROM users WHERE name LIKE "%Joe"')
		
			'db.users.find({"name":/Joe$/})': (topic) ->
				assert.equal(topic, 'db.users.find({"name":/Joe$/})')

		'SELECT * FROM users WHERE name LIKE "Joe"':
			topic: -> mql.processSql('SELECT * FROM users WHERE name LIKE "Joe"')
		
			'db.users.find({"name":/^Joe$/})': (topic) ->
				assert.equal(topic, 'db.users.find({"name":/^Joe$/})')

		'SELECT * FROM users WHERE age>33 AND age<=40':
			topic: -> mql.processSql('SELECT * FROM users WHERE age>33 AND age<=40')
		
			'db.users.find({"age":{$gt:33,$lte:40}})': (topic) ->
				assert.equal(topic, 'db.users.find({"age":{$gt:33,$lte:40}})')
	
	.run()
