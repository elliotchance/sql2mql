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
		
			'db.users.find({age:33})': (topic) ->
				assert.equal(topic, 'db.users.find({age:33})')

		'SELECT a,b FROM users WHERE age=33':
			topic: -> mql.processSql('SELECT a,b FROM users WHERE age=33')
		
			'db.users.find({age:33}, {a:1,b:1})': (topic) ->
				assert.equal(topic, 'db.users.find({age:33}, {a:1,b:1})')

		'SELECT * FROM users WHERE age=33 ORDER BY name':
			topic: -> mql.processSql('SELECT * FROM users WHERE age=33 ORDER BY name')
		
			'db.users.find({age:33}).sort({name:1})': (topic) ->
				assert.equal(topic, 'db.users.find({age:33}).sort({name:1})')

		'SELECT * FROM users WHERE age>33':
			topic: -> mql.processSql('SELECT * FROM users WHERE age>33')
		
			'db.users.find({age:{$gt:33}})': (topic) ->
				assert.equal(topic, 'db.users.find({age:{$gt:33}})')
	
	.run()
