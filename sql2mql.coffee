class Token

	# the name of the token
	token = null
	
	# the value captured for this token
	value = null
	
	constructor: (@token, @value = null) ->
		# nothing really to do here
	
	toString: () ->
		return @value

class RightOperand

	# @var Token
	operator = null
	
	# @var Token
	right = null
	
	constructor: (@operator, @right) ->
		# do nothing here
	
	toString: () ->
		return @operator.toString() + " " + @right.toString()

# this class handles cases when the BSON can be reduced to a more simple from	
class MqlOptimizer

	getArrayKeys: (obj) ->
		keys = []
		for k, v of obj
			keys.push(k)
		return keys

	optimizeBson: (bson) ->
		# return anything that is not an object unharmed
		if typeof bson != 'object'
			return bson
		
		out = {}
		for k, v of bson
			if k == '$and'
				# check if all the keys relate to the same field
				field = @getArrayKeys(v[0])
				for k2, v2 of v
					if field.toString() != @getArrayKeys(v2)[0].toString()
						field = null
						break
				
				# if field still retains a value then all the keys are the same and we can simplify
				# this expression
				if field
					out[field] = {}
					for k2, v2 of v
						op = @getArrayKeys(v2[field])[0]
						out[field][op] = v2[field][op]
				else
					# no such luck
					out['and'] = v
			else
				# there is nothing we can do, so just pass it through
				out[k] = v
		
		return out

class MqlTranslator
	
	constructor: () ->
		# do nothing
		
	convertOperator: (op) ->
		switch op
			when '>' then '$gt'
			when '<' then '$lt'
			when '>=' then '$gte'
			when '<=' then '$lte'
			when '=' then '$eq'
			when '!=' then '$ne'
			when 'AND' then '$and'
			else throw new Error("Unknown operator '" + op + "'")
		
	createRegexFromLike: (str) ->
		# strip quotes
		str = str.substr(1, str.length - 2)
		
		# start and end anchors
		if str.charAt(0) != '%'
			str = '^' + str
		if str.charAt(str.length - 1) != '%'
			str = str + '$'
		
		# handle %
		str = str.replace(/%/g, '')
		
		return '/' + str + '/'
	
	# @var fmt Can be one of 'object' or 'string'
	translateMql: (tree, fmt = 'object') ->
		final = null
		
		switch tree.operatorClass
			when 'SINGLE'
				final = @translateMql(tree.left)
				
			when 'LOGICAL'
				if tree.rights.length == 0
					final = @translateMql(tree.left)
				else
					op = @convertOperator(tree.rights[0].operator.token)
					r = {}
					r[op] = [ @translateMql(tree.left) ]
					for k, v of tree.rights
						r[op].push(@translateMql(v.right))
					final = r
				
			when 'COMPARISON'
				r = {}
				
				switch tree.rights[0].operator.token
					when '='
						r[@translateMql(tree.left)] = @translateMql(tree.rights[0].right)
					when 'LIKE'
						regex = @createRegexFromLike(@translateMql(tree.rights[0].right))
						r[@translateMql(tree.left)] = regex
					else
						op = @convertOperator(tree.rights[0].operator.token)
						
						r[@translateMql(tree.left)] = {}
						r[@translateMql(tree.left)][op] = @translateMql(tree.rights[0].right)
			
				final = r
				
			when 'TOKEN'
				# try and autocast
				if tree.left.value.match(/^[0-9]+$/)
					final = tree.left.value * 1
				else
					final = tree.left.value
				
			else
				throw new Error("Unknown operatorClass '" + tree.operatorClass + "'")
				
		# before we finish up we run the raw BSON through the optimizer to see if it can be
		# simplified
		optimizer = new MqlOptimizer()
		final = optimizer.optimizeBson(final)
				
		# if the format is 'object' we just return the object we've created
		if fmt == 'object'
			return final
			
		# if the format is 'string' we pretty-reduce it
		if fmt == 'string'
			return @prettyReduce(final)
		
		# we have been provided some invalid format
		throw new Error("Unknown format '" + fmt + "'")
	
	prettyReduce: (tree) ->
		# before we transverse, check to see if all the keys are integers
		isArray = true		
		for k, v of tree
			if not k.match(/^[0-9]+$/)
				isArray = false
				break
		
		if isArray
			r = '['
			for k, v of tree
				if r.length > 1
					r += ","
					
				if typeof v == 'object'
					r += @prettyReduce(v)
				else
					r += v
			r += ']'
		else
			r = '{'
			for k, v of tree
				if r.length > 1
					r += ","
					
				if k.charAt(0) != '$'
					k = '"' + k + '"'
					
				if typeof v == 'object'
					r += k + ":" + @prettyReduce(v)
				else
					r += k + ':' + v
			r += '}'
		
		return r

class BinaryExpression
	
	constructor: (@operatorClass, @left, @rights = []) ->
		# do nothing
	
	addRight: (operator, right) ->
		rightOperand = new RightOperand(operator, right)
		@rights.push(rightOperand)
		return rightOperand
	
	toString: () ->
		r = ''
		r += '(' if @rights.length > 0
		r += @left.toString()
		for key, value of @rights
			r += " " + value.toString()
		r += ')' if @rights.length > 0
		return r
		
class Expression extends BinaryExpression
	
	constructor: (@left, @rights = []) ->
		super("SINGLE", @left, @rights)
		
class AndExpression extends BinaryExpression
	
	constructor: (@left, @rights = []) ->
		super("LOGICAL", @left, @rights)
		
class ComparisonExpression extends BinaryExpression
	
	constructor: (@left, @rights = []) ->
		super("COMPARISON", @left, @rights)
		
class SingleExpression extends BinaryExpression
	
	constructor: (@left, @rights = []) ->
		super("TOKEN", @left, @rights)

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
			return new Token('<EOF>')
	
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
				return new Token(tokenName, firstMatch[0])
		
		return new Token(token, value)
	
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
		'>=': ">="
		'<=': "<="
		'!=': "!="
		
		'*': "\\*"
		',': ","
		'=': "="
		'>': ">"
		'<': "<"
		
		# keywords
		'AND': "AND"
		'BY': "BY"
		'FROM': "FROM"
		'LIKE': "LIKE"
		'ORDER': "ORDER"
		'SELECT': "SELECT"
		'WHERE': "WHERE"
		
		# SINGLES
		'IDENTIFIER': "[a-zA-Z]+"
		'INTEGER': '[0-9]+'
		'STRING_SINGLE': "'.*'"
		'STRING_DOUBLE': '".*"'
	
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
		msg = "Found " + next.token + " '" + next.value + "' but expected one of:"
		for k, v of paths
			msg += " " + k
		throw new Error(msg)
		
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
	
	# @return Expression
	consumeExpression: () ->
		return new Expression(@consumeAnd())
		
	# @return AndExpression
	consumeAnd: () ->
		ex = new AndExpression(@consumeComparison())
		if @peekNextToken().token == 'AND'
			ex.addRight(@assertNextToken('AND'), @consumeExpression())
		return ex
		
	# @return ComparisonExpression
	consumeComparison: () ->
		r = new ComparisonExpression(@consumeSingle())
		
		direction = {
			'=': () =>
				@assertNextToken('=')
			'>': () =>
				@assertNextToken('>')
			'<': () =>
				@assertNextToken('<')
			'>=': () =>
				@assertNextToken('>=')
			'<=': () =>
				@assertNextToken('<=')
			'!=': () =>
				@assertNextToken('!=')
			'LIKE': () =>
				@assertNextToken('LIKE')
		}
		if direction[@peekNextToken().token]
			r.addRight(@branch(direction), @consumeSingle())
		
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
	
	# @return SingleExpression
	consumeSingle: () ->
		# consume a single value
		return new SingleExpression(@branch({
			'IDENTIFIER': () =>
				@nextToken()
			'INTEGER': () =>
				@nextToken()
			'STRING_SINGLE': () =>
				@nextToken()
			'STRING_DOUBLE': () =>
				@nextToken()
		}))
		
class Mql

	processSql: (sql) ->
		lexer = new MqlLexer(sql)
		parser = new MqlParser(lexer)
		tree = parser.consumeSql()
		translator = new MqlTranslator()
		
		# filter fields
		where = null
		if tree.where
			where = translator.translateMql(tree.where, 'string')
		
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

# if this is run from the command line execute the parser now
if process.argv[2]
	mql = new Mql()
	sql = process.argv[2]
	console.log(mql.processSql(sql))

# export module
module.exports = {
	Mql: Mql
}
