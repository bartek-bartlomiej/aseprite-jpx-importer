zlib_deflate = dofile("../zlib/deflate.lua")

SIGNATURE = "\137\080\078\071\013\010\026\010"

local *

decode_png = (input) ->
  index = validate_signature(input)
  index, width, height = validate_image_header_chunk(input, index)
  index, data_index, data_length = validate_image_data_chunk(input, index)
  index = validate_end_marker_chunk(input, index)
  
  buffer = decompress_data(input, data_index, data_length)
  
  -- debug, decompress should be bug-free
  expected_size = height * (1 + width * 4)
  unless expected_size == #buffer
    error("Incorrect size of decompressed data (#{expected_size}, got #{buffer.n})")

  {
    :width
    :height
    bytes: reconstruct_pixel_data(buffer, width, height)
  }


validate_signature = (input) ->
  for i = 1, #SIGNATURE
    unless string.byte(input, i) == string.byte(SIGNATURE, i)
      error("Invalid PNG signature")

  #SIGNATURE + 1


validate_image_header_chunk = (input, index) ->
  index, data_index, data_length = validate_chunk(input, index, "IHDR")

  unless data_length == 13
    error("Wrong length of IHDR data (expected 13 bytes, got #{data_length}")

  data_index, width = read_integer_from_string(input, data_index)
  data_index, height = read_integer_from_string(input, data_index)
  data_index, bit_depth = read_byte_from_string(input, data_index)
  data_index, color_type = read_byte_from_string(input, data_index)
  data_index, compression_method = read_byte_from_string(input, data_index)
  data_index, filter_method = read_byte_from_string(input, data_index)
  data_index, interlace_method = read_byte_from_string(input, data_index)

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


validate_image_data_chunk = (input, index) ->
  validate_chunk(input, index, "IDAT")


validate_end_marker_chunk = (input, index) ->
  index, _, data_length = validate_chunk(input, index, "IEND")

  unless data_length == 0
    error("Wrong length of IEND data (expected 0 bytes, got #{data_length}")

  unless index == #input + 1
    error("Unexpected trailing garbage")

  index


validate_chunk = (input, index, type) ->
  index, data_length = get_chunk_length(input, index) 
  index = validate_chunk_type(input, index, type)
  index, data_index = get_chunk_date_index(input, index, data_length)
  index, _ = get_chunk_crc(input, index) -- CRC not checked

  -- TODO: validate using CRC

  index, data_index, data_length

  
get_chunk_length = (input, index) ->
  read_integer_from_string(input, index)


validate_chunk_type = (input, index, type) ->
  for i = 1, #type
    unless string.byte(input, index + i - 1) == string.byte(type, i)
      error("Unexpected type (expected #{type}, got #{string.sub(input, index, index + 3)})")

  index + 4


get_chunk_date_index = (input, index, length) ->
  index + length, index


get_chunk_crc = (input, index) ->
  index + 4, nil -- CRC not checked


read_integer_from_string = (input, index) ->
  result = 0
  for i = index, index + 3
    byte = string.byte(input, i)
    result = (result << 8) + byte

  index + 4, result 


read_byte_from_string = (input, index) ->
  index + 1, string.byte(input, index)


decompress_data = (input, data_index, data_length) ->
  zlib_deflate(input, data_index, data_length)


BYTES_PER_PIXEL = 4

reconstruct_pixel_data = (buffer, width, height) ->
  stride = width * BYTES_PER_PIXEL
  input_size = height * (stride + 1)
  output_size = height * stride

  read_index = 1
  write_index = 1

  for scan_line_index = 1, height
    read_index, filter_type = read_byte_from_table(buffer, read_index)
    reconstruct = get_reconstruct_method(filter_type)

    for byte_index = 1, stride
      read_index, filtered_byte = read_byte_from_table(buffer, read_index)

      byte = reconstruct(filtered_byte, buffer, scan_line_index, stride, byte_index)
      write_index = write_byte_to_table(buffer, byte, write_index)

  while write_index <= input_size
    write_index = write_byte_to_table(buffer, nil, write_index)

  buffer.n = output_size

  buffer

  
read_byte_from_table = (buffer, index) ->
  index + 1, buffer[index]


write_byte_to_table = (buffer, byte, index) ->
  buffer[index] = byte
    
  index + 1


get_reconstruct_method = (filter_type) ->
  reconstruct = reconstruct_methods[filter_type]

  unless reconstruct
    error("unknown filter type #{filter_type}")

  reconstruct


filter_types =
  NONE: 0
  SUB: 1
  UP: 2
  AVERAGE: 3
  PAETH: 4

reconstruct_methods =
  [filter_types.NONE]: (filtered_byte, _, _, _, _) ->
    filtered_byte

  [filter_types.SUB]: (filtered_byte, buffer, scan_line_index, stride, byte_index) ->
    (filtered_byte + 
      get_reconstructed_byte_from_left(buffer, scan_line_index, stride, byte_index)
    ) & 0xff

  [filter_types.UP]: (filtered_byte, buffer, scan_line_index, stride, byte_index) ->
    (filtered_byte + 
      get_reconstructed_byte_from_top(buffer, scan_line_index, stride, byte_index)
    ) & 0xff

  [filter_types.AVERAGE]: (filtered_byte, buffer, scan_line_index, stride, byte_index) ->
    (filtered_byte + (
      get_reconstructed_byte_from_left(buffer, scan_line_index, stride, byte_index) +
      get_reconstructed_byte_from_top(buffer, scan_line_index, stride, byte_index)
    ) // 2) & 0xff

  [filter_types.PAETH]: (filtered_byte, buffer, scan_line_index, stride, byte_index) ->
    (filtered_byte + get_Paeth_predictor(
      get_reconstructed_byte_from_left(buffer, scan_line_index, stride, byte_index),
      get_reconstructed_byte_from_top(buffer, scan_line_index, stride, byte_index),
      get_reconstructed_byte_from_top_left(buffer, scan_line_index, stride, byte_index)
    )) & 0xff


get_reconstructed_byte_from_left = (buffer, scan_line_index, stride, byte_index) ->
  if byte_index > BYTES_PER_PIXEL
    index = (scan_line_index - 1) * stride + byte_index - BYTES_PER_PIXEL
    buffer[index]
  else
    0


get_reconstructed_byte_from_top = (buffer, scan_line_index, stride, byte_index) ->
  if scan_line_index > 1
    index = (scan_line_index - 2) * stride + byte_index
    buffer[index]
  else
    0


get_reconstructed_byte_from_top_left = (buffer, scan_line_index, stride, byte_index) ->
  if scan_line_index > 1 and byte_index > BYTES_PER_PIXEL
    index = (scan_line_index - 2) * stride + byte_index - BYTES_PER_PIXEL
    buffer[index]
  else
    0


abs = math.abs

get_Paeth_predictor = (a, b, c) ->
  p = a + b + c
  distance_a = abs(p - a)
  distance_b = abs(p - b)
  distance_c = abs(p - c)
  
  if ((distance_a <= distance_b) and (distance_a <= distance_c))
    distance_a
  elseif distance_b <= distance_c
    distance_b
  else
    distance_c


decode_png
