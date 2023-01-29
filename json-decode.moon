local *

SPACE = string.byte(" ")
BACKSPACE = string.byte("\b")
CARRIAGE_RETURN = string.byte("\r")
NEW_LINE = string.byte("\n")
TAB = string.byte("\t")
FORMFEED = string.byte("\f")

SLASH = string.byte("/")
BACKSLASH = string.byte("\\")

UNICODE_ESCAPE = string.byte("u")

MINUS = string.byte("-")
ZERO = string.byte("0")
NINE = string.byte("9")

CURLY_OPEN_BRACKET = string.byte("{")
SQUARE_OPEN_BRACKET = string.byte("[")
DOUBLE_QUOTE = string.byte("\"")
CURLY_CLOSE_BRACKET = string.byte("}")
SQUARE_CLOSE_BRACKET = string.byte("]")

COLON = string.byte(":")
COMMA = string.byte(",")

UNICODE_ESCAPE_PATTERN = "^[dD][89aAbB]%x%x\\u%x%x%x%x"
UNICODE_ESCAPE_SIMPLE_PATTERN = "^%x%x%x%x"

create_set = (...) -> { select(i, ...), true for i = 1, select("#", ...) } 

whitespace_characters = create_set(
  SPACE,
  TAB,
  CARRIAGE_RETURN,
  NEW_LINE
)

delimiters = create_set(
  SPACE,
  TAB,
  CARRIAGE_RETURN,
  NEW_LINE,
  SQUARE_CLOSE_BRACKET,
  CURLY_CLOSE_BRACKET,
  COMMA
)

escape_characters_map =
  [SLASH]: "/"
  [BACKSLASH]: "\\"
  [DOUBLE_QUOTE]: "\""
  [string.byte("b")]: "\b"
  [string.byte("f")]: "\f"
  [string.byte("n")]: "\n"
  [string.byte("r")]: "\r"
  [string.byte("t")]: "\t"

json_literals = create_set(
  "true",
  "false",
  "null"
)

literals_map =
  ["true"]: true
  ["false"]: false
  ["null"]: nil


decode = (input) ->
  validate_input(input)

  parse(input)
  

validate_input = (input) ->
  type = type(input)
  unless type == "string"
    error("expected argument of type string, got #{type}") 


parse = (input) ->
  index = 1

  index = skip_whitespaces(input, index)
  result, index = parse_next_token(input, index)

  index = skip_whitespaces(input, index)
  unless #input <= index 
    raise_error(input, index, "trailing garbage")

  result


parse_next_token = (input, index) ->
  first_byte = string.byte(input, index)
  parse_token = token_parsers[first_byte]

  unless parse_token
    raise_error(input, index, "unexpected character '#{string.char(first_byte)}'")
  
  parse_token(input, index)


parse_object = (input, index) ->
  parsed = {}
  index += 1

  while true
    complete, index = is_object_completed(input, index)
    return parsed, index if complete

    key, index = parse_key(input, index)
    index = check_colon_presence(input, index)
    value, index = parse_value(input, index)
    
    parsed[key] = value

    complete, index = is_object_completed(input, index)
    return parsed, index if complete
    
    index = check_comma_presence(input, index, CURLY_CLOSE_BRACKET)


is_object_completed = (input, index) ->
  index = skip_whitespaces(input, index)

  if string.byte(input, index) == CURLY_CLOSE_BRACKET
    true, index + 1
  else
    false, index
  

parse_key = (input, index) ->
  index = skip_whitespaces(input, index)
  unless string.byte(input, index) == DOUBLE_QUOTE
    raise_error(input, index, "expected string for key")

  parse_string(input, index)


check_colon_presence = (input, index) ->
  index = skip_whitespaces(input, index)
  unless string.byte(input, index) == COLON
    raise_error(input, index, "expected ':' after key")

  index + 1


parse_value = (input, index) ->
  index = skip_whitespaces(input, index)
  
  parse_next_token(input, index)


check_comma_presence = (input, index, end_byte) ->
  unless string.byte(input, index) == COMMA
    raise_error(input, index, "expected '#{string.char(end_byte)}' or ','")
  
  index + 1


parse_array = (input, index) ->
  result, size = {}, 0
  index += 1

  while true
    complete, index = is_array_completed(input, index)
    return result, index if complete
    
    value, index = parse_value(input, index)
    size += 1
    result[size] = value

    complete, index = is_array_completed(input, index)
    return result, index if complete

    index = check_comma_presence(input, index, SQUARE_CLOSE_BRACKET)


is_array_completed = (input, index) ->
  index = skip_whitespaces(input, index)
  if string.byte(input, index) == SQUARE_CLOSE_BRACKET
    true, index + 1
  else
    false, index


parse_literal = (input, index) ->
  delimiter_index = find_next_character_index(input, index, delimiters)
  stringified = string.sub(input, index, delimiter_index - 1)

  unless json_literals[stringified]
    raise_error(input, index, "invalid literal '#{stringified}'")

  literals_map[stringified], delimiter_index


parse_number = (input, index) ->
  delimiter_index = find_next_character_index(input, index, delimiters)
  stringified = string.sub(input, index, delimiter_index - 1)
  number = tonumber(stringified)
  
  unless number
    raise_error(input, index, "invalid number '#{stringified}'")

  number, delimiter_index


parse_string = (input, index) ->
  result, size = {}, 0

  i = index + 1
  j = i

  input_size = #input
  while i <= input_size
    byte = string.byte(input, i)

    unless byte >= 32
      raise_error(input, i, "control character in string")

    if byte == BACKSLASH
      size += 1
      result[size] = string.sub(input, j, i - 1)

      i += 1
      byte = string.byte(input, i)

      if byte == UNICODE_ESCAPE
        hex = string.match(input, UNICODE_ESCAPE_PATTERN, i + 1)
        hex or= string.match(input, UNICODE_ESCAPE_SIMPLE_PATTERN, i + 1)
        
        unless hex
          raise_error(input, i - 1, "invalid unicode escape in string")
        
        size += 1
        result[size] = parse_unicode_escape(hex)

        i += #hex
      else
        unless escape_characters_map[byte]
          raise_error(input, i - 1, "invalid escape char '#{string.char(byte)}' in string")
        
        size += 1
        result[size] = escape_characters_map[byte]

      j = i + 1

    elseif byte == DOUBLE_QUOTE
      size += 1
      result[size] = string.sub(input, j, i - 1)
      
      return table.concat(result), i + 1

    i += 1

  raise_error(input, index, "expected closing quote for string")


parse_unicode_escape = (stringified) ->
  a = tonumber(string.sub(stringified, 1, 4), 16)
  b = tonumber(string.sub(stringified, 7, 10), 16)
  
  if b
    convert_codepoint_to_utf8((a - 0xd800) * 0x400 + (b - 0xdc00) + 0x10000)
  else
    convert_codepoint_to_utf8(a)


convert_codepoint_to_utf8 = (n) ->
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  
  f = math.floor

  if n <= 0x7f
    string.char(n)
  elseif n <= 0x7ff then
    string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128, f(n % 4096 / 64) + 128, n % 64 + 128)
  else
    error(string.format("invalid unicode codepoint '%x'", n))


token_parsers = with {}
    [CURLY_OPEN_BRACKET] = parse_object
    
    [SQUARE_OPEN_BRACKET] = parse_array
    
    [string.byte(key, 1)] = parse_literal for key, _ in pairs(json_literals)
    
    [key] = parse_number for key = ZERO, NINE
    [MINUS] = parse_number

    [DOUBLE_QUOTE] = parse_string
    

skip_whitespaces = (input, index) ->
  for i = index, #input
    return i unless whitespace_characters[string.byte(input, i)]

  #input + 1


find_next_character_index = (input, index, set) ->
  for i = index, #input
    return i if set[string.byte(input, i)]
  
  #input + 1


raise_error = (input, index, message) ->
  line_count, column_index = 1, 1
  for i = 1, index - 1
    if string.byte(input, i) == NEW_LINE
      line_count += 1
      column_index = 1
    else
      column_index += 1

  error("#{message} at line #{line_count}, column #{column_index}")


decode
