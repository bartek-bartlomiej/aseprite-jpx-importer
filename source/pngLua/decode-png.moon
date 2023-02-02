SIGNATURE = "\137\080\078\071\013\010\026\010"

chunk_types =
  header: 
  data: "IDAT"
  end_marker: "IEND"

local *

decode_png = (input) -> 
  index = validate_signature(input)
  index, width, height = parse_image_header_chunk(input, index)
  index, data = parse_image_data_chunk(input, index)
  index = validate_end_marker_chunk(input, index)
    
  {
    :width
    :height
    -- bytes: data
  }


validate_signature = (input) ->
  for i = 1, #SIGNATURE
    unless string.byte(input, i) == string.byte(SIGNATURE, i)
      error("Invalid PNG signature")

  #SIGNATURE + 1


parse_image_header_chunk = (input, index) ->
  index, data_index, data_length = read_chunk_data(input, index, "IHDR")

  unless data_length == 13
    error("Wrong length of IHDR data (expected 13 bytes, got #{data_length}")

  data_index, width = read_integer(input, data_index)
  data_index, height = read_integer(input, data_index)
  data_index, bit_depth = read_byte(input, data_index)
  data_index, color_type = read_byte(input, data_index)
  data_index, compression_method = read_byte(input, data_index)
  data_index, filter_method = read_byte(input, data_index)
  data_index, interlace_method = read_byte(input, data_index)

  unless width > 0
    error("Invalid width (got #{width})")

  unless height > 0
    error("Invalid height (got #{height})")

  unless compression_method == 0
    error("Invalid compression method")

  unless filter_method == 0
    error("Invalid filter method")

  unless bit_depth == 8
    error("Only a bit depth of 8 is supported")

  unless color_type == 6
    error("Only Truecolor with alpha is supported")

  unless interlace_method == 0
    error("Only no interlacing is supported")

  index, width, height


parse_image_data_chunk = (input, index) ->
  index, data_index, data_length = read_chunk_data(input, index, "IDAT")

  index, nil -- TODO


validate_end_marker_chunk = (input, index) ->
  index, _, _ = read_chunk_data(input, index, "IEND")

  unless index == #input + 1
    error("Unexpected trailing garbage")

  index


read_chunk_data = (input, index, type) ->
  index, data_length = get_chunk_length(input, index) 
  index = validate_chunk_type(input, index, type)
  index, data_index = get_chunk_date_index(input, index, data_length)
  index, _ = get_chunk_crc(input, index) -- CRC not checked

  -- TODO: validate using crc

  index, data_index, data_length

  
get_chunk_length = (input, index) ->
  read_integer(input, index)


validate_chunk_type = (input, index, type) ->
  for i = 1, #type
    unless string.byte(input, index + i - 1) == string.byte(type, i)
      error("Unexpected type (expected #{type}, got #{string.sub(input, index, index + 3)})")

  index + 4


get_chunk_date_index = (input, index, length) ->
  index + length, index


get_chunk_crc = (input, index) ->
  index + 4, nil -- CRC not checked


read_integer = (input, index) ->
  result = 0
  for i = index, index + 3
    byte = string.byte(input, i)
    result = (result << 8) + byte

  index + 4, result 


read_byte = (input, index) ->
  index + 1, string.byte(input, index)


decode_png
