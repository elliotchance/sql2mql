class Lexer

	# setup the lexer with the string it is going to tokenize
	constructor: (@stream = '') ->
		# nothing to do here
	
	# This will first attempt to find the token in IGNORES, if so it is forgotten. Otherwise it will
	# attempt to match a token in the order they appear in TOKENS. If a token can not be matched
	# then null is returned.
	nextToken: (peek = false) ->
		# hit EOF?
		if @stream.length == 0
			return { token: '<EOF>', value: null }
	
		# consume all ignores first
		while true
			foundMatch = false
			for tokenName, tokenRegex of @IGNORES
				regex = new RegExp('^' + tokenRegex)
				firstMatch = regex.exec(@stream)
				break if not firstMatch
					
				# crop this token off the front
				@stream = @stream.substr(firstMatch[0].length)
				foundMatch = true
			
			break if not foundMatch
		
		# consume the real token
		for tokenName, tokenRegex of @TOKENS
			regex = new RegExp('^' + tokenRegex)
			firstMatch = regex.exec(@stream)
			if firstMatch
				# only crop if we are not peeking
				if not peek
					@stream = @stream.substr(firstMatch[0].length)
				return { token: tokenName, value: firstMatch[0] }
		
		return { token: null, value: null }
	
	peekNextToken: () ->
		return @nextToken(true)

class MqlLexer extends Lexer

	# any time we encounter these tokens we can consume and ignore
	IGNORES:
		# whitespace
		'WHITESPACE': "\\s+"

	# tokens we may encounter, highest importance first
	TOKENS:
		# symbols
		'*': "\\*"
		',': ","
		'=': "="
		
		# keywords
		'BY': "BY"
		'FROM': "FROM"
		'ORDER': "ORDER"
		'SELECT': "SELECT"
		'WHERE': "WHERE"
		
		# IDENTIFIER
		'IDENTIFIER': "[a-zA-Z]+"
		'INTEGER': '[0-9]+'
	
	constructor: (@stream) ->
		super(@stream)

class Parser
	
	constructor: (@lexer) ->
		# nothing needs to be done here
	
	branch: (paths) ->
		# peek one token
		next = @lexer.peekNextToken()
		
		# if the token is not understood stop here
		if next.token == null
			throw new Error("Can not understand '" + next.value + "'")
			
		# the token we consume must be one of the paths provided
		for tokenName, tokenPath of paths
			if next.token == tokenName
				return tokenPath()
		
		# the token was not one of the possible branches
		throw new Error("Found " + next.token + " '" + next.value + "' but expected one of: " +
			paths)
		
	consume: (token, success) ->
		# peek the next token and see if it is what we are looking for
		next = @lexer.nextToken(true)
		if(next.token == token)
			return success(next.token)
		
		# otherwise we have a problem
		throw new Error("Found " + next.token + " '" + next.value + "' but expected " + token)
		
	assertNextToken: (wantedToken) ->
		next = @lexer.nextToken()
		@assertToken(wantedToken, next.token)
		return next
	
	assertToken: (expectedToken, actualToken) ->
		if actualToken != expectedToken
			throw new Error("Token assertion failed: Expected " + expectedToken + " but actual " +
				"token is " + actualToken)
		return actualToken
		
	nextToken: (peek = false) ->
		return @lexer.nextToken(peek)
		
	peekNextToken: () ->
		return @lexer.peekNextToken()

class MqlParser extends Parser

	consumeSql: () ->
		# begin
		r = @branch({
			'SELECT': () => @consumeSelect()
		})
		
		# consume EOF
		#@assertNextToken('<EOF>')
		
		return r

	consumeSelect: () ->
		r = {}
		
		# consume 'SELECT'
		r.token = @assertNextToken('SELECT').value
		
		# we must read a field list
		r.fields = @consumeFieldList()
		
		# FROM is a must
		@assertNextToken('FROM')
		r.from = @assertNextToken('IDENTIFIER').value
		
		# WHERE is optional
		if @peekNextToken().token == 'WHERE'
			r.where = @consumeWhere()
			
		# ORDER BY is optional
		if @peekNextToken().token == 'ORDER'
			r.orderBy = @consumeOrderBy()
		
		# all good
		return r
		
	consumeWhere: () ->
		# consume 'WHERE'
		@assertNextToken('WHERE')
		
		# consume expression
		return @consumeExpression()
		
	consumeOrderBy: () ->
		# consume 'ORDER BY'
		@assertNextToken('ORDER')
		@assertNextToken('BY')
		
		# consume expression
		return @consumeFieldList()
		
	consumeExpression: () ->
		return @consumeEquals()
		
	consumeEquals: () ->
		r = {}
		
		r.left = @assertNextToken('IDENTIFIER').value
		r.operator = @assertNextToken('=').value
		r.right = @assertNextToken('INTEGER').value
		
		return r
	
	consumeFieldList: () ->
		r = []
		
		# we must have at least one field
		r.push(@consumeField())
		
		# are their more fields?
		while @peekNextToken().token == ','
			# consume ','
			@assertNextToken(',')
			
			r.push(@consumeField())
		
		return r
	
	consumeField: () ->
		# consume a single field
		return @branch({
			'*': () =>
				return @nextToken().value
			'IDENTIFIER': () =>
				return @nextToken().value
		})
		
class Mql

	processSql: (sql) ->
		lexer = new MqlLexer(sql)
		parser = new MqlParser(lexer)
		tree = parser.consumeSql()
		
		# filter fields
		where = null
		if tree.where
			where = '{' + tree.where.left + ':' + tree.where.right + '}'
		
		# select fields
		fields = null
		if tree.fields.length > 1 or tree.fields[0] != '*'
			fields = "{"
			for key, field of tree.fields
				fields += ',' if key > 0
				fields += field + ":1"
			fields += "}"
		
		# convert the tree into a MongoDB call
		mql = ''
		if fields == null and where == null
			mql = 'db.' + tree.from + '.find()'
		else if fields != null and where == null
			mql = 'db.' + tree.from + '.find({}, ' + fields + ')'
		else if fields == null and where != null
			mql = 'db.' + tree.from + '.find(' + where + ')'
		else
			mql = 'db.' + tree.from + '.find(' + where + ', ' + fields + ')'
			
		# sort
		if tree.orderBy
			mql += ".sort({"
			for key, value of tree.orderBy
				mql += ',' if key > 0
				mql += value + ":1"
			mql += "})"
		
		return mql

if process.argv[2]
	mql = new Mql()
	sql = process.argv[2]
	console.log(mql.processSql(sql))

# export module
module.exports = {
	Mql: Mql
}
