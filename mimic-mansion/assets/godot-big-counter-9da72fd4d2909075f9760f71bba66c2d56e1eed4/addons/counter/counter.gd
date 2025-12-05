@tool
@icon("res://addons/counter/icon.svg")
class_name Counter extends Node
## Counter with a number and a total number.
##
## Note that the Counter's numbers are all stored using the Big class, which
## is (for the purposes of this counter) an inner class accessed using
## Counter.Big
##
## You must give the Counter node a Timer child. Every tick_secs seconds,
## number will be increased by per_tick. per_tick is computed from a number of
## variables -- ((tick_base + tick_extra) ^ tick_exponent) * tick_multiplier.
## Each of these can be manipulated by setting directly, or by using,
## for tick_X, register_X(n), deregister_X(n), or reset_X(n). The register_ and
## deregister_ methods act as though you are adding one, and then another,
## instead of just increasing the number linearly -- there's a difference, for
## exponents and multipliers.
##
## You must not set per_tick directly. However, you can set number directly, or
## manipulate it using increase_by() or decrease_by().
## There's also reset_number(). total_number can be set directly, but can only
## increase -- decreasing it will throw an error.
##
## You can also set tick_secs directly. This will pass through to the timer.
## tick_enabled also passes through (it starts and stops, rather than pauses)
## Other methods for interacting with the Timer:
## get_timer(), start_tick(), and stop_tick()

#region signals
## Emitted with current number, new number, and the sign of the change in value
signal number_changed
## emitted with old per_tick, and new per_tick
signal per_tick_changed
## emitted with no variables
signal ticked
## Emitted with the passed-in multiplier, the old tick_multiplier, and the new tick_multiplier
signal multiplier_registered
## Emitted with the passed-in multiplier, the old tick_multiplier, and the new tick_multiplier
signal multiplier_deregistered
signal multiplier_changed
## Emitted with the passed-in exponent, the old tick_exponent, and the new tick_exponent
signal exponent_registered
## Emitted with the passed-in exponent, the old tick_exponent, and the new tick_exponent
signal exponent_deregistered
signal exponent_changed
## Emitted with the passed-in extra, the old tick_extra, and the new tick_extra
signal extra_registered
## Emitted with the passed-in extra, the old tick_extra, and the new tick_extra
signal extra_deregistered
signal extra_changed
#endregion
#region @export variables
## How much the number goes up per tick, at first.
@export var initial_per_tick: int = 1
## Settings related to the Timer
@export_group("Tick Timer")
## If true, number goes up on tick. If false, number goes up continuously,
## averaging per_tick each tick.
@export var discrete_tick := true
## Mirrors $Timer.wait_time
@export var tick_secs := 1.0:
	get:
		if is_instance_of(tick_timer, Timer):
			return tick_timer.wait_time
		else:
			return tick_secs
	set(value):
		if is_instance_of(tick_timer, Timer):
			tick_timer.wait_time = value
		else:
			tick_secs = value
@export var tick_enabled := true:
	get:
		if is_instance_of(tick_timer, Timer):
			return not tick_timer.is_stopped()
		else:
			return tick_enabled
	set(value):
		if is_instance_of(tick_timer, Timer):
			if value:
				tick_timer.start()
			else:
				tick_timer.stop()
		else:
			tick_enabled = value
#endregion
#region per_tick properties
## number goes up by this much per tick, notwithstanding extras/exponents/etc
var tick_base: Big:
	get:
		return _tick_base
	set(value):
		_update_pertick_wrapper("_tick_base", value)
var _tick_base := Big.new(initial_per_tick, 0)
## _tick_extra added to tick_base
var tick_extra: Big:
	get:
		return _tick_extra
	set(value):
		_update_pertick_wrapper("_tick_extra", value)
var _tick_extra := Big.new(0)
## _tick_base+_tick_extra raised to _tick_exponent
var tick_exponent: Big:
	get:
		return _tick_exponent
	set(value):
		# clamp exponent between 0 and 9.99e3
		value = Big.maxValue(Big.minValue(value, Big.new(9.99, 2)), 0)
		_update_pertick_wrapper("_tick_exponent", value)
var _tick_exponent := Big.new(1, 0)
## (_tick_base+_tick_extra)^_tick_exponent multiplied by _tick_multiplier
var tick_multiplier: Big:
	get:
		return _tick_multiplier
	set(value):
		_update_pertick_wrapper("_tick_multiplier", value)
var _tick_multiplier := Big.new(1, 0)
## actual value by which number goes up each tick -- computed
var per_tick: Big:
	get:
		if _per_tick_modified:
			#region EXPENSIVE
			_per_tick = tick_base.plus(tick_extra).power(tick_exponent.toFloat()).multiply(tick_multiplier)
			#endregion
			_per_tick_modified = false
		return _per_tick
	set(value):
		assert(false, "per_tick was set directly -- it's always computed")
var _per_tick: Big = Big.new(0)
# set in _update_pertick_wrapper
var _per_tick_modified: bool = false
#endregion
#region other properties
## number goes up, people are happy. Number also can go down.
var number: Big = Big.new(0, 0):
	set(value):
		# Increase total_number if necessary
		if number.isLessThan(value):
			total_number = total_number.plus(value.minus(number))
		# Set label
		var old_number = number
		number = value
		emit_signal("number_changed", old_number, number)
## number goes up, total_number goes up also. total_number never goes down.
var total_number: Big = number:
	set(value):
		# Throw errors if the total_number is messed up
		assert(total_number.isLessThanOrEqualTo(value), "total_number decreased")
		assert(total_number.isGreaterThanOrEqualTo(number), "total_number somehow became smaller than number") 
		# Set label
		total_number = value
var tick_timer: Timer:
	set(value):
		tick_timer = value
		if _editor_guard():
			return
		tick_timer.timeout.connect(_on_tick_timeout)
#endregion
#region Override Functions
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	var has_timer: bool = get_timer() != null
	
	if not has_timer:
		warnings.append("You should add a Timer node as a child here.")
	
	return warnings


func _ready() -> void:
	if _editor_guard():
		return
	var was_enabled = tick_enabled
	get_timer().stop()
	tick_timer = get_timer()
	if was_enabled:
		start_tick()


func _process(delta: float) -> void:
	if _editor_guard():
		return
	if not tick_timer.is_stopped() and not discrete_tick:
		_increase_by_per_tick(delta/tick_secs)


#endregion
#region Validators/Utility Functions
## Returns the Counter's Timer.
func get_timer() -> Timer:
	for child in self.get_children():
		if is_instance_of(child, Timer):
			return child
	return null


#endregion
#region Listener Functions
func _on_tick_timeout() -> void:
	if discrete_tick:
		_increase_by_per_tick(1.0)
	emit_signal("ticked")


#endregion
#region API Functions
## Resets the counter entirely
func reset() -> void:
	# This will update per_tick once, but then it'll always be 0 until we change
	# multiplier again.
	tick_exponent = Big.new(0)
	tick_multiplier = Big.new(0)
	tick_base = Big.new(initial_per_tick, 0)
	reset_exponent()
	reset_extra()
	reset_number()
	reset_multiplier()


## Increases number by x
func increase_by(x) -> void:
	number = number.plus(x)


## Decreases number by x
func decrease_by(x) -> void:
	number = number.minus(x)


## Resets number to 1
func reset_number() -> void:
	number = Big.new(1.0)


## Registers an additional per-tick value
func register_extra(extra) -> void:
	var old_tick_extra = tick_extra
	tick_extra = tick_extra.plus(extra)
	emit_signal("extra_registered", extra, old_tick_extra, tick_extra)
	_log_regdereg(extra, old_tick_extra, tick_extra)


## Deregisters an additional per-tick value
func deregister_extra(extra) -> void:
	var old_tick_extra = tick_extra
	tick_extra = tick_extra.minus(extra)
	emit_signal("extra_deregistered", extra, old_tick_extra, tick_extra)
	_log_regdereg(extra, old_tick_extra, tick_extra)


## Resets _tick_extra to 0
func reset_extra() -> void:
	tick_extra = Big.new(0, 0)


## Registers an additional per-tick multiplier
func register_multiplier(multiplier) -> void:
	var old_tick_multiplier = tick_multiplier
	tick_multiplier = tick_multiplier.multiply(multiplier)
	emit_signal("multiplier_registered", multiplier, old_tick_multiplier, tick_multiplier)
	_log_regdereg(multiplier, old_tick_multiplier, tick_multiplier)


## Deregisters an additional per-tick multiplier
func deregister_multiplier(multiplier) -> void:
	var old_tick_multiplier = tick_multiplier
	tick_multiplier = tick_multiplier.divide(multiplier)
	emit_signal("multiplier_deregistered", multiplier, old_tick_multiplier, tick_multiplier)
	_log_regdereg(multiplier, old_tick_multiplier, tick_multiplier)


## Resets _tick_multiplier to 1
func reset_multiplier() -> void:
	tick_multiplier = Big.new(1, 0)


## Registers an additional per-tick exponent
func register_exponent(exponent) -> void:
	var old_tick_exponent = tick_exponent
	tick_exponent = tick_exponent.multiply(exponent)
	emit_signal("exponent_registered", exponent, old_tick_exponent, tick_exponent)
	_log_regdereg(exponent, old_tick_exponent, tick_exponent)


## Deregisters an additional per-tick exponent
func deregister_exponent(exponent) -> void:
	var old_tick_exponent = tick_exponent
	tick_exponent = tick_exponent.divide(exponent)
	emit_signal("exponent_deregistered", exponent, old_tick_exponent, tick_exponent)
	_log_regdereg(exponent, old_tick_exponent, tick_exponent)


## Resets _tick_exponent to 1
func reset_exponent() -> void:
	tick_exponent = Big.new(1, 0)


## Start the automatic tick
func start_tick() -> void:
	tick_enabled = true


## Stop the automatic tick
func stop_tick() -> void:
	tick_enabled = false


#endregion
#region private methods
## Increases number by per_tick
func _increase_by_per_tick(delta: float) -> void:
	increase_by(per_tick.multiply(delta))


func _editor_guard():
	return Engine.is_editor_hint()


func _update_pertick_wrapper(property: StringName, value) -> void:
	if _editor_guard():
		return
	
	# _per_tick_modified should not be true right now
	assert(_per_tick_modified == false, "Tried to update per_tick while _per_tick_modified was already true")
	# Gets the current per_tick value
	var old_per_tick = per_tick
	# Sets the property to value -- property will typically be _tick_*, acting
	# as actual storage for the tick_* property.
	#(eg tick_exponent and _tick_exponent)
	set(property, value)
	# Set _per_tick_modified to true
	_per_tick_modified = true
	# Emit signal. Accessing per_tick here while _per_tick_modified is true
	# causes per_tick to be recomputed. This is computationally expensive.
	emit_signal("per_tick_changed", old_per_tick, per_tick)
	# Emit other signals as needed.
	match property:
		"_tick_exponent":
			emit_signal("exponent_changed")
		"_tick_multiplier":
			emit_signal("multiplier_changed")
		"_tick_extra":
			emit_signal("extra_changed")


func _log_regdereg(val, old_var, new_var) -> void:
	#print_stack()
	#if is_instance_of(val, Big):
		#val = val.toScientific()
	#if is_instance_of(old_var, Big):
		#old_var = old_var.toScientific()
	#if is_instance_of(new_var, Big):
		#new_var = new_var.toScientific()
	#print_debug("Registered value: ", typeof(val), " ", val,
			#"\nOld variable: ", typeof(old_var), " ", old_var,
			#"\nNew variable: ", typeof(new_var), " ", new_var)
	return
#endregion


## Big number class for use in idle / incremental games and other games that needs very large numbers
##
## Can format large numbers using a variety of notation methods:[br]
## AA notation like AA, AB, AC etc.[br]
## Metric symbol notation k, m, G, T etc.[br]
## Metric name notation kilo, mega, giga, tera etc.[br]
## Long names like octo-vigin-tillion or millia-nongen-quin-vigin-tillion (based on work by Landon Curt Noll)[br]
## Scientic notation like 13e37 or 42e42[br]
## Long strings like 4200000000 or 13370000000000000000000000000000[br][br]
## Please note that this class has limited precision and does not fully support negative exponents[br]
class Big extends RefCounted:
	#region CONSTANTS
	## Metric Symbol Suffixes
	const suffixes_metric_symbol: Dictionary = {
		"0": "", 
		"1": "k", 
		"2": "M", 
		"3": "G", 
		"4": "T", 
		"5": "P", 
		"6": "E", 
		"7": "Z", 
		"8": "Y", 
		"9": "R", 
		"10": "Q",
	}
	## Metric Name Suffixes
	const suffixes_metric_name: Dictionary = {
		"0": "", 
		"1": "kilo", 
		"2": "mega", 
		"3": "giga", 
		"4": "tera", 
		"5": "peta", 
		"6": "exa", 
		"7": "zetta", 
		"8": "yotta", 
		"9": "ronna", 
		"10": "quetta", 
	}
	## AA Alphabet
	const alphabet_aa: Array[String] = [
		"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", 
		"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
	]
	## Latin Ones Prefixes
	const latin_ones: Array[String] = [
		"",
		"un",
		"duo",
		"tre",
		"quattuor",
		"quin",
		"sex",
		"septen",
		"octo",
		"novem",
	]
	## Latin Tens Prefixes
	const latin_tens: Array[String] = [
		"",
		"dec",
		"vigin",
		"trigin",
		"quadragin",
		"quinquagin",
		"sexagin",
		"septuagin",
		"octogin",
		"nonagin",
	]
	## Latin Hundreds Prefixes
	const latin_hundreds: Array[String] = [
		"",
		"cen",
		"duocen",
		"trecen",
		"quadringen",
		"quingen",
		"sescen",
		"septingen",
		"octingen",
		"nongen",
	]
	## Latin Special Prefixes
	const latin_special: Array[String] = [
		"",
		"mi",
		"bi",
		"tri",
		"quadri",
		"quin",
		"sex",
		"sept",
		"oct",
		"non",
	]
	## Maximum Big Number Mantissa
	const MANTISSA_MAX: float = 1209600.0
	## Big Number Mantissa floating-point precision
	const MANTISSA_PRECISION: float = 0.0000001
	## int (signed 64-bit) minimum value
	const INT_MIN: int = -9223372036854775808
	## int (signed 64-bit) maximum value
	const INT_MAX: int = 9223372036854775807
	#endregion
	## AA suffixes keps in dictionary to prevent generating each of them again and again
	## It's a static var on purpose
	static var suffixes_aa: Dictionary = {
		"0": "", 
		"1": "k", 
		"2": "m", 
		"3": "b", 
		"4": "t", 
		"5": "aa", 
		"6": "ab", 
		"7": "ac", 
		"8": "ad", 
		"9": "ae", 
		"10": "af", 
		"11": "ag", 
		"12": "ah", 
		"13": "ai", 
		"14": "aj", 
		"15": "ak", 
		"16": "al", 
		"17": "am", 
		"18": "an", 
		"19": "ao", 
		"20": "ap", 
		"21": "aq", 
		"22": "ar", 
		"23": "as", 
		"24": "at", 
		"25": "au", 
		"26": "av", 
		"27": "aw", 
		"28": "ax", 
		"29": "ay", 
		"30": "az", 
		"31": "ba", 
		"32": "bb", 
		"33": "bc", 
		"34": "bd", 
		"35": "be", 
		"36": "bf", 
		"37": "bg", 
		"38": "bh", 
		"39": "bi", 
		"40": "bj", 
		"41": "bk", 
		"42": "bl", 
		"43": "bm", 
		"44": "bn", 
		"45": "bo", 
		"46": "bp", 
		"47": "bq", 
		"48": "br", 
		"49": "bs", 
		"50": "bt", 
		"51": "bu", 
		"52": "bv", 
		"53": "bw", 
		"54": "bx", 
		"55": "by", 
		"56": "bz", 
		"57": "ca",
	}
	## Various options to control the string presentation of Big Numbers
	static var options = {
		"default_mantissa": 1.0,
		"default_exponent": 0,
		"dynamic_decimals": false, 
		"dynamic_numbers": 4, 
		"small_decimals": 2, 
		"thousand_decimals": 2, 
		"big_decimals": 2, 
		"scientific_decimals": 2, 
		"logarithmic_decimals": 2, 
		"maximum_trailing_zeroes": 3,
		"thousand_separator": ",", 
		"decimal_separator": ".", 
		"suffix_separator": "", 
		"reading_separator": "", 
		"thousand_name": "thousand",
	}
	## Big Number Mantissa
	var mantissa: float
	## Big Number Exponent
	var exponent: int

	#region static methods
	## Verifies (or converts) an argument into a Big number
	static func _typeCheck(n) -> Big:
		if n is Big:
			return n
		var result := Big.new(n)
		return result


	## Warns if Big number's mantissa exceeds max
	static func _sizeCheck(m: float) -> void:
		if m > MANTISSA_MAX:
			printerr("Big Error: Mantissa \"" + str(m) + "\" exceeds MANTISSA_MAX. Use exponent or scientific notation")


	## [url=https://en.wikipedia.org/wiki/Normalized_number]Normalize[/url] a Big number
	static func normalize(big: Big) -> void:
		# Store sign if negative
		var is_negative := false
		if big.mantissa < 0:
			is_negative = true
			big.mantissa *= -1
			
		big.mantissa = snapped(big.mantissa, MANTISSA_PRECISION)
		if big.mantissa < 1.0 or big.mantissa >= 10.0:
			var diff: int = floor(log10(big.mantissa))
			if diff > -10 and diff < 248:
				var div = 10.0 ** diff
				if div > MANTISSA_PRECISION:
					big.mantissa /= div
					big.exponent += diff
		while big.exponent < 0:
			# modified 11/18/2025
			if is_inf(big.exponent):
				break
			big.mantissa *= 0.1
			big.exponent += 1
		while big.mantissa >= 10.0:
			# modified 11/18/2025
			if is_inf(big.mantissa):
				break
			big.mantissa *= 0.1
			big.exponent += 1
		if big.mantissa == 0:
			big.mantissa = 0.0
			big.exponent = 0
		big.mantissa = snapped(big.mantissa, MANTISSA_PRECISION)
		
		# Return sign if negative
		if (is_negative):
			big.mantissa *= -1


	## Returns the absolute value of a number in Big format
	static func absolute(x) -> Big:
		var result := Big.new(x)
		result.mantissa = abs(result.mantissa)
		return result


	## Adds two numbers and returns the Big number result [br][br]
	static func add(x, y) -> Big:
		x = Big._typeCheck(x)
		y = Big._typeCheck(y)
		var result := Big.new(x)
		
		var exp_diff: float = y.exponent - x.exponent
		
		if exp_diff < 248.0:
			var scaled_mantissa: float = y.mantissa * 10 ** exp_diff
			result.mantissa = x.mantissa + scaled_mantissa
		elif x.isLessThan(y): # When difference between values is too big, discard the smaller number
			result.mantissa = y.mantissa 
			result.exponent = y.exponent
		Big.normalize(result)
		return result


	## Subtracts two numbers and returns the Big number result
	static func subtract(x, y) -> Big:
		x = Big._typeCheck(x)
		y = Big._typeCheck(y)
		var negated_y := Big.new(-y.mantissa, y.exponent)
		return add(negated_y, x)


	## Multiplies two numbers and returns the Big number result
	static func times(x, y) -> Big:
		x = Big._typeCheck(x)
		y = Big._typeCheck(y)
		var result := Big.new()
		
		var new_exponent: int = y.exponent + x.exponent
		var new_mantissa: float = y.mantissa * x.mantissa
		while new_mantissa >= 10.0:
			new_mantissa /= 10.0
			new_exponent += 1
		result.mantissa = new_mantissa
		result.exponent = new_exponent
		Big.normalize(result)
		return result


	## Divides two numbers and returns the Big number result
	static func division(x, y) -> Big:
		x = Big._typeCheck(x)
		y = Big._typeCheck(y)
		var result := Big.new(x)
		
		if y.mantissa > -MANTISSA_PRECISION and y.mantissa < MANTISSA_PRECISION:
			printerr("Big Error: Divide by zero or less than " + str(MANTISSA_PRECISION))
			return x
		var new_exponent = x.exponent - y.exponent
		var new_mantissa = x.mantissa / y.mantissa
		while new_mantissa > 0.0 and new_mantissa < 1.0:
			new_mantissa *= 10.0
			new_exponent -= 1
		result.mantissa = new_mantissa
		result.exponent = new_exponent
		Big.normalize(result)
		return result


	# Raises a Big number to the nth power and returns the Big number result
	static func powers(x: Big, y) -> Big: # x = 5, y = 2010.0 ; x = 5, y = 2010
		var result := Big.new(x) # Big.new(5) = 5E0
		if typeof(y) == TYPE_INT:
			if y <= 0:
				if y < 0:
					printerr("Big Error: Negative exponents are not supported!")
				result.mantissa = 1.0
				result.exponent = 0
				return result
			
			var y_mantissa: float = 1.0
			var y_exponent: int = 0
			
			while y > 1:
				Big.normalize(result) # result = 5E0 ; 2.5E1
				if y % 2 == 0:
					result.exponent *= 2 # 0
					result.mantissa **= 2 # 25
					y = y / 2 #1005
				else:
					y_mantissa = result.mantissa * y_mantissa # 2.5
					y_exponent = result.exponent + y_exponent # 1
					result.exponent *= 2 # 2
					result.mantissa **= 2 # 6.25
					y = (y - 1) / 2
			
			result.exponent = y_exponent + result.exponent
			result.mantissa = y_mantissa * result.mantissa
			Big.normalize(result)
			return result
		elif typeof(y) == TYPE_FLOAT:
			if result.mantissa == 0:
				return result
			
			# fast track
			var temp: float = result.exponent * y # 0.0
			var newMantissa = result.mantissa ** y # INF
			if (round(y) == y
					and temp <= INT_MAX
					and temp >= INT_MIN
					and is_finite(temp)
			):
				if is_finite(newMantissa):
					result.mantissa = newMantissa
					result.exponent = int(temp)
					Big.normalize(result)
					return result
			
			# a bit slower, still supports floats
			var newExponent: int = int(temp) # 0
			var residue: float = temp - newExponent # 0.0
			newMantissa = 10 ** (y * Big.log10(result.mantissa) + residue) # probably INF
			if is_finite(newMantissa):
				result.mantissa = newMantissa
				result.exponent = newExponent
				Big.normalize(result)
				return result
			
			if round(y) != y:
				printerr("Big Error: Power function does not support large floats, use integers!")
			
			return powers(x, int(y))
		elif y is Big:
			# warning - this might be slow!
			if y.isEqualTo(0):
				return Big.new(1)
			if y.isLessThan(0):
				printerr("Big Error: Negative exponents are not supported!")
				return Big.new(0)

			var exponent_decremented:Big = y.minus(1)
			while exponent_decremented.isGreaterThan(0):
				result.multiplyEquals(x)
				exponent_decremented.minusEquals(1)

			return result
		else:
			printerr("Big Error: Unknown/unsupported data type passed as an exponent in power function!")
			return x


	## Square Roots a given Big number and returns the Big number result
	static func root(x: Big) -> Big:
		var result := Big.new(x)
		
		if result.exponent % 2 == 0:
			result.mantissa = sqrt(result.mantissa)
			@warning_ignore("integer_division")
			result.exponent = result.exponent / 2
		else:
			result.mantissa = sqrt(result.mantissa * 10)
			@warning_ignore("integer_division")
			result.exponent = (result.exponent - 1) / 2
		Big.normalize(result)
		return result


	## Modulos a number and returns the Big number result
	static func modulo(x, y) -> Big:
		x = Big._typeCheck(x)
		y = Big._typeCheck(y)
		var result = x.divide(y)
		result = Big.roundDown(result)
		result = Big.times(result, y)
		result = Big.subtract(x, result)
		return result


	## Rounds down a Big number
	static func roundDown(x: Big) -> Big:
		if x.exponent == 0:
			x.mantissa = floor(x.mantissa)
		else:
			var precision := 1.0
			for i in range(min(8, x.exponent)):
				precision /= 10.0
			if precision < MANTISSA_PRECISION:
				precision = MANTISSA_PRECISION
			x.mantissa = floor(x.mantissa / precision) * precision
		return x


	## Equivalent of [code]min(Big, Big)[/code]
	static func minValue(m, n) -> Big:
		m = Big._typeCheck(m)
		# modified 11/18/2025
		n = Big._typeCheck(n)
		if m.isLessThan(n):
			return m
		else:
			return n


	## Equivalent of [code]max(Big, Big)[/code]
	static func maxValue(m, n) -> Big:
		# modified 11/18/2025
		m = Big._typeCheck(m)
		n = Big._typeCheck(n)
		if m.isGreaterThan(n):
			return m
		else:
			return n
	## sort function for use with [code]Array.sort_custom(Big.sort_increasing)[/code]
	static func sort_increasing(a:Big, b:Big):
		if a.isLessThan(b):
			return true
		else:
			return false


	## sort function for use with [code]Array.sort_custom(Big.sort_decreasing)[/code]
	static func sort_decreasing(a:Big, b:Big):
		if a.isLessThan(b):
			return false
		else:
			return true


	static func log10(x) -> float:
		return log(x) * 0.4342944819032518
	## Sets the Default (m)antissa and (e)xponent options, these are the default mantissa and exponent used when creating a new Big number
	static func setDefaultValue(m: float, e: int) -> void:
		setDefaultMantissa(m)
		setDefaultExponent(e)


	## Sets the Default mantissa option, this is the default mantissa used when creating a new Big number
	static func setDefaultMantissa(value: float) -> void:
		options["default_mantissa"] = value


	## Sets the Default Exponent option, this is the default exponent used when creating a new Big number
	static func setDefaultExponent(value: int) -> void:
		options["default_exponent"] = value


	## Sets the Thousand name option
	static func setThousandName(name: String) -> void:
		options.thousand_name = name


	## Sets the Thousand Separator option
	static func setThousandSeparator(separator: String) -> void:
		options.thousand_separator = separator


	## Sets the Decimal Separator option
	static func setDecimalSeparator(separator: String) -> void:
		options.decimal_separator = separator


	## Sets the Suffix Separator option
	static func setSuffixSeparator(separator: String) -> void:
		options.suffix_separator = separator


	## Sets the Reading Separator option
	static func setReadingSeparator(separator: String) -> void:
		options.reading_separator = separator


	## Sets the Dynamic Decimals option
	static func setDynamicDecimals(d: bool) -> void:
		options.dynamic_decimals = d


	## Sets the Dynamic numbers digits option
	static func setDynamicNumbers(d: int) -> void:
		options.dynamic_numbers = d


	## Sets the maximum trailing zeroes option
	static func setMaximumTrailingZeroes(d: int) -> void:
		options.maximum_trailing_zeroes = d


	## Sets the small decimal digits option
	static func setSmallDecimals(d: int) -> void:
		options.small_decimals = d


	## Sets the thousand decimal digits option
	static func setThousandDecimals(d: int) -> void:
		options.thousand_decimals = d


	## Sets the big decimal digits option
	static func setBigDecimals(d: int) -> void:
		options.big_decimals = d


	## Sets the scientific notation decimal digits option
	static func setScientificDecimals(d: int) -> void:
		options.scientific_decimals = d


	## Sets the logarithmic notation decimal digits option
	static func setLogarithmicDecimals(d: int) -> void:
		options.logarithmic_decimals = d
	#endregion

	func _init(m: Variant = options["default_mantissa"], e: int = options["default_exponent"]) -> void:
		if m is Big:
			mantissa = m.mantissa
			exponent = m.exponent
		elif typeof(m) == TYPE_STRING:
			var scientific: PackedStringArray = m.split("e")
			mantissa = float(scientific[0])
			exponent = int(scientific[1]) if scientific.size() > 1 else 0
		else:
			if typeof(m) != TYPE_INT and typeof(m) != TYPE_FLOAT:
				printerr("Big Error: Unknown data type passed as a mantissa!")
			mantissa = m
			exponent = e
		Big._sizeCheck(mantissa)
		Big.normalize(self)


	## Equivalent of [code]Big + n[/code]
	func plus(n) -> Big:
		return Big.add(self, n)


	## Equivalent of [code]Big += n[/code]
	func plusEquals(n) -> Big:
		var new_value = Big.add(self, n)
		mantissa = new_value.mantissa
		exponent = new_value.exponent
		return self


	## Equivalent of [code]Big - n[/code]
	func minus(n) -> Big:
		return Big.subtract(self, n)


	## Equivalent of [code]Big -= n[/code]
	func minusEquals(n) -> Big:
		var new_value: Big = Big.subtract(self, n)
		mantissa = new_value.mantissa
		exponent = new_value.exponent
		return self


	## Equivalent of [code]Big * n[/code]
	func multiply(n) -> Big:
		return Big.times(self, n)


	## Equivalent of [code]Big *= n[/code]
	func multiplyEquals(n) -> Big:
		var new_value: Big = Big.times(self, n)
		mantissa = new_value.mantissa
		exponent = new_value.exponent
		return self


	## Equivalent of [code]Big / n[/code]
	func divide(n) -> Big:
		return Big.division(self, n)


	## Equivalent of [code]Big /= n[/code]
	func divideEquals(n) -> Big:
		var new_value: Big = Big.division(self, n)
		mantissa = new_value.mantissa
		exponent = new_value.exponent
		return self


	## Equivalent of [code]Big % n[/code]
	func mod(n) -> Big:
		return Big.modulo(self, n)


	## Equivalent of [code]Big %= n[/code]
	func modEquals(n) -> Big:
		var new_value := Big.modulo(self, n)
		mantissa = new_value.mantissa
		exponent = new_value.exponent
		return self


	## Equivalent of [code]Big ** n[/code]
	func power(n) -> Big:
		return Big.powers(self, n)


	## Equivalent of [code]Big **= n[/code]
	func powerEquals(n) -> Big:
		var new_value: Big = Big.powers(self, n)
		mantissa = new_value.mantissa
		exponent = new_value.exponent
		return self


	## Equivalent of [code]sqrt(Big)[/code]
	func squareRoot() -> Big:
		return Big.root(self)


	## Equivalent of [code]Big = sqrt(Big)[/code]
	func squared() -> Big:
		var new_value := Big.root(self)
		mantissa = new_value.mantissa
		exponent = new_value.exponent
		return self


	## Equivalent of [code]Big == n[/code]
	func isEqualTo(n) -> bool:
		n = Big._typeCheck(n)
		Big.normalize(n)
		return n.exponent == exponent and is_equal_approx(n.mantissa, mantissa)


	## Equivalent of [code]Big > n[/code]
	func isGreaterThan(n) -> bool:
		return !isLessThanOrEqualTo(n)


	## Equivalent of [code]Big >== n[/code]
	func isGreaterThanOrEqualTo(n) -> bool:
		return !isLessThan(n)


	## Equivalent of [code]Big < n[/code]
	func isLessThan(n) -> bool:
		n = Big._typeCheck(n)
		Big.normalize(n)
		if (mantissa == 0
				and (n.mantissa > MANTISSA_PRECISION or mantissa < MANTISSA_PRECISION)
				and n.mantissa == 0
		):
			return false
		if exponent < n.exponent:
			if exponent == n.exponent - 1 and mantissa > 10*n.mantissa:	
				return false #9*10^3 > 0.1*10^4
			return true
		elif exponent == n.exponent:
			if mantissa < n.mantissa:
				return true
			return false
		else:
			if exponent == n.exponent + 1 and mantissa * 10 < n.mantissa:
				return true
			return false


	## Equivalent of [code]Big <= n[/code]
	func isLessThanOrEqualTo(n) -> bool:
		n = Big._typeCheck(n)
		Big.normalize(n)
		if isLessThan(n):
			return true
		if n.exponent == exponent and is_equal_approx(n.mantissa, mantissa):
			return true
		return false


	func absLog10() -> float:
		return exponent + Big.log10(abs(mantissa))


	func ln() -> float:
		return 2.302585092994045 * logN(10)


	func logN(base) -> float:
		return (2.302585092994046 / log(base)) * (exponent + Big.log10(mantissa))


	func pow10(value: int) -> void:
		mantissa = 10 ** (value % 1)
		exponent = int(value)


	## Converts the Big Number into a string
	func toString() -> String:
		var mantissa_decimals := 0
		if str(mantissa).find(".") >= 0:
			mantissa_decimals = str(mantissa).split(".")[1].length()
		if mantissa_decimals > exponent:
			if exponent < 248:
				return str(mantissa * 10 ** exponent)
			else:
				return toPlainScientific()
		else:
			var mantissa_string := str(mantissa).replace(".", "")
			for _i in range(exponent-mantissa_decimals):
				mantissa_string += "0"
			return mantissa_string


	## Converts the Big Number into a string (in plain Scientific format)
	func toPlainScientific() -> String:
		return str(mantissa) + "e" + str(exponent)


	## Converts the Big Number into a string (in Scientific format)
	func toScientific(no_decimals_on_small_values = false, force_decimals = false) -> String:
		if exponent < 3:
			var decimal_increments: float = 1 / (10 ** options.scientific_decimals / 10)
			var value := str(snappedf(mantissa * 10 ** exponent, decimal_increments))
			var split := value.split(".")
			if no_decimals_on_small_values:
				return split[0]
			if split.size() > 1:
				for i in range(options.logarithmic_decimals):
					if split[1].length() < options.scientific_decimals:
						split[1] += "0"
				return split[0] + options.decimal_separator + split[1].substr(0,min(options.scientific_decimals, options.dynamic_numbers - split[0].length() if options.dynamic_decimals else options.scientific_decimals))
			else:
				return value
		else:
			var split := str(mantissa).split(".")
			if split.size() == 1:
				split.append("")
			if force_decimals:
				for i in range(options.scientific_decimals):
					if split[1].length() < options.scientific_decimals:
						split[1] += "0"
			return split[0] + options.decimal_separator + split[1].substr(0,min(options.scientific_decimals, options.dynamic_numbers-1 - str(exponent).length() if options.dynamic_decimals else options.scientific_decimals)) + "e" + str(exponent)


	## Converts the Big Number into a string (in Logarithmic format)
	func toLogarithmic(no_decimals_on_small_values = false) -> String:
		var decimal_increments: float = 1 / (10 ** options.logarithmic_decimals / 10)
		if exponent < 3:
			var value := str(snappedf(mantissa * 10 ** exponent, decimal_increments))
			var split := value.split(".")
			if no_decimals_on_small_values:
				return split[0]
			if split.size() > 1:
				for i in range(options.logarithmic_decimals):
					if split[1].length() < options.logarithmic_decimals:
						split[1] += "0"
				return split[0] + options.decimal_separator + split[1].substr(0,min(options.logarithmic_decimals, options.dynamic_numbers - split[0].length() if options.dynamic_decimals else options.logarithmic_decimals))
			else:
				return value
		var dec := str(snappedf(abs(log(mantissa) / log(10) * 10), decimal_increments))
		dec = dec.replace(".", "")
		for i in range(options.logarithmic_decimals):
			if dec.length() < options.logarithmic_decimals:
				dec += "0"
		var formated_exponent := formatExponent(exponent)
		dec = dec.substr(0, min(options.logarithmic_decimals, options.dynamic_numbers - formated_exponent.length() if options.dynamic_decimals else options.logarithmic_decimals))
		return "e" + formated_exponent + options.decimal_separator + dec


	## Formats an exponent for string format
	func formatExponent(value) -> String:
		if value < 1000:
			return str(value)
		var string := str(value)
		var string_mod := string.length() % 3
		var output := ""
		for i in range(0, string.length()):
			if i != 0 and i % 3 == string_mod:
				output += options.thousand_separator
			output += string[i]
		return output


	## Converts the Big Number into a float
	func toFloat() -> float:
		return snappedf(float(str(mantissa) + "e" + str(exponent)),0.01)


	func getLongName(european_system = false, prefix="") -> String:
		if exponent < 6:
			return ""
		else:
			return prefix + _latinPrefix(european_system) + options.reading_separator + _tillionOrIllion(european_system) + _llionOrLliard(european_system)


	## Converts the Big Number into a string (in American Long Name format)
	func toAmericanName(no_decimals_on_small_values = false) -> String:
		return toLongName(no_decimals_on_small_values, false)


	## Converts the Big Number into a string (in European Long Name format)
	func toEuropeanName(no_decimals_on_small_values = false) -> String:
		return toLongName(no_decimals_on_small_values, true)


	## Converts the Big Number into a string (in Latin Long Name format)
	func toLongName(no_decimals_on_small_values = false, european_system = false) -> String:
		if exponent < 6:
			if exponent > 2:
				return toPrefix(no_decimals_on_small_values) + options.suffix_separator + options.thousand_name
			else:
				return toPrefix(no_decimals_on_small_values)

		var suffix = _latinPrefix(european_system) + options.reading_separator + _tillionOrIllion(european_system) + _llionOrLliard(european_system)

		return toPrefix(no_decimals_on_small_values) + options.suffix_separator + suffix


	## Converts the Big Number into a string (in Metric Symbols format)
	func toMetricSymbol(no_decimals_on_small_values = false) -> String:
		@warning_ignore("integer_division")
		var target := int(exponent / 3)

		if not suffixes_metric_symbol.has(str(target)):
			return toScientific()
		else:
			return toPrefix(no_decimals_on_small_values) + options.suffix_separator + suffixes_metric_symbol[str(target)]


	## Converts the Big Number into a string (in Metric Name format)
	func toMetricName(no_decimals_on_small_values = false) -> String:
		@warning_ignore("integer_division")
		var target := int(exponent / 3)

		if not suffixes_metric_name.has(str(target)):
			return toScientific()
		else:
			return toPrefix(no_decimals_on_small_values) + options.suffix_separator + suffixes_metric_name[str(target)]


	## Converts the Big Number into a string (in AA format)
	func toAA(no_decimals_on_small_values = false, use_thousand_symbol = true, force_decimals=false) -> String:
		@warning_ignore("integer_division")
		var target := int(exponent / 3)
		var aa_index := str(target)
		var suffix := ""

		if not suffixes_aa.has(aa_index):
			var offset := target + 22
			var base := alphabet_aa.size()
			while offset > 0:
				offset -= 1
				var digit := offset % base
				suffix = alphabet_aa[digit] + suffix
				offset /= base
			suffixes_aa[aa_index] = suffix
		else:
			suffix = suffixes_aa[aa_index]

		if not use_thousand_symbol and target == 1:
			suffix = ""

		var prefix = toPrefix(no_decimals_on_small_values, use_thousand_symbol, force_decimals)

		return prefix + options.suffix_separator + suffix


	func _latinPower(european_system) -> int:
		if european_system:
			@warning_ignore("integer_division")
			return int(exponent / 3) / 2
		@warning_ignore("integer_division")
		return int(exponent / 3) - 1


	func _latinPrefix(european_system) -> String:
		var ones := _latinPower(european_system) % 10
		var tens := int(_latinPower(european_system) / floor(10)) % 10
		@warning_ignore("integer_division")
		var hundreds := int(_latinPower(european_system) / 100) % 10
		@warning_ignore("integer_division")
		var millias := int(_latinPower(european_system) / 1000) % 10

		var prefix := ""
		if _latinPower(european_system) < 10:
			prefix = latin_special[ones] + options.reading_separator + latin_tens[tens] + options.reading_separator + latin_hundreds[hundreds]
		else:
			prefix = latin_hundreds[hundreds] + options.reading_separator + latin_ones[ones] + options.reading_separator + latin_tens[tens]

		for _i in range(millias):
			prefix = "millia" + options.reading_separator + prefix

		return prefix.lstrip(options.reading_separator).rstrip(options.reading_separator)


	func _tillionOrIllion(european_system) -> String:
		if exponent < 6:
			return ""
		var powerKilo := _latinPower(european_system) % 1000
		if powerKilo < 5 and powerKilo > 0 and _latinPower(european_system) < 1000:
			return ""
		if (
				powerKilo >= 7 and powerKilo <= 10
				or int(powerKilo / floor(10)) % 10 == 1
		):
			return "i"
		return "ti"


	func _llionOrLliard(european_system) -> String:
		if exponent < 6:
			return ""
		if int(exponent/floor(3)) % 2 == 1 and european_system:
			return "lliard"
		return "llion"


	func toPrefix(no_decimals_on_small_values = false, use_thousand_symbol=true, force_decimals=true, scientic_prefix=false) -> String:
		var number: float = mantissa
		if not scientic_prefix:
			var hundreds = 1
			for _i in range(exponent % 3):
				hundreds *= 10
			number *= hundreds

		var split := str(number).split(".")
		if split.size() == 1:
			split.append("")
		if force_decimals:
			var max_decimals = max(max(options.small_decimals, options.thousand_decimals), options.big_decimals)
			for i in range(max_decimals):
				if split[1].length() < max_decimals:
					split[1] += "0"
		
		if no_decimals_on_small_values and exponent < 3:
			return split[0]
		elif exponent < 3:
			if options.small_decimals == 0 or split[1] == "":
				return split[0]
			else:
				return split[0] + options.decimal_separator + split[1].substr(0,min(options.small_decimals, options.dynamic_numbers - split[0].length() if options.dynamic_decimals else options.small_decimals))
		elif exponent < 6:
			if options.thousand_decimals == 0 or (split[1] == "" and use_thousand_symbol):
				return split[0]
			else:
				if use_thousand_symbol: # when the prefix is supposed to be using with a K for thousand
					for i in range(options.maximum_trailing_zeroes):
						if split[1].length() < options.maximum_trailing_zeroes:
							split[1] += "0"
					return split[0] + options.decimal_separator + split[1].substr(0,min(options.thousand_decimals, options.dynamic_numbers - split[0].length() if options.dynamic_decimals else 3))
				else:
					for i in range(options.maximum_trailing_zeroes):
						if split[1].length() < options.maximum_trailing_zeroes:
							split[1] += "0"
					return split[0] + options.thousand_separator + split[1].substr(0,3)
		else:
			if options.big_decimals == 0 or split[1] == "":
				return split[0]
			else:
				return split[0] + options.decimal_separator + split[1].substr(0,min(options.big_decimals, options.dynamic_numbers - split[0].length() if options.dynamic_decimals else options.big_decimals))
