deflate = dofile("deflate.lua")

SIGNATURE = "\137\080\078\071\013\010\026\010"

chunk_types =
  header: 
  data: "IDAT"
  end_marker: "IEND"

local *

decode_png = (input) ->
  index = validate_signature(input)
  index, width, height = parse_image_header_chunk(input, index)
  index, data_index, data_length = parse_image_data_chunk(input, index)
  index = validate_end_marker_chunk(input, index)
  
  -- TODO: simplify zlib.decompress
  i = data_index - 1
  j = data_index + data_length - 1
  o = {}
  o.read = () =>
    i += 1
    string.byte(input, i) if i <= j
  
  x =
    n: 0
  
  deflate.inflate_zlib({
    input: o
    output: (byte) -> 
      x.n += 1
      x[x.n] = byte
    disable_crc: true
  })

  -- debug, decompress should be bug-free
  expected_size = height * (1 + width * 4)
  unless expected_size == x.n
    error("Incorrect size of decompressed data (#{expected_size}, got #{x.n})")

  --print(table.concat(x, ","))

  {
    :width
    :height
    bytes: reconstruct_pixel_data(x, width, height)
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
  read_chunk_data(input, index, "IDAT")


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

bytes_per_pixel = 4

reconstruct_pixel_data = (data, width, height) ->
  stride = width * bytes_per_pixel
  input_size = height * (stride + 1)
  output_size = height * stride

  read_index = 1
  write_index = 1
  output = {}

  for scan_line_index = 1, height
    read_index, filter_type = read_index + 1, data[read_index] -- TODO DRY
    reconstruct = get_reconstruct_method(filter_type)

    for byte_index = 1, stride
      read_index, filtered_byte = read_index + 1, data[read_index]

      byte = reconstruct(filtered_byte, output, scan_line_index, stride, byte_index)
      write_index = write_byte(output, byte, write_index)

  unless write_index == output_size + 1
    error("I messed up")

  --while write_index <= input_size
  --  write_index = write_byte(data, nil, write_index)

  output.n = output_size

  output
  
  

get_reconstruct_method = (filter_type) ->
  reconstruct = reconstruct_methods[filter_type]

  print(filter_type) unless filter_type == 0

  unless reconstruct
    error("unknown filter type #{filter_type}")

  reconstruct


reconstruct_byte_with_none_filter = (filtered_byte, _, _, _, _) ->
  filtered_byte


reconstruct_byte_with_sub_filter = (filtered_byte, bytes, scan_line_index, stride, byte_index) ->
  (filtered_byte + get_reconstructed_byte_from_left(bytes, scan_line_index, stride, byte_index)) & 0xff


reconstruct_byte_with_up_filter = (filtered_byte, bytes, scan_line_index, stride, byte_index) ->
  (filtered_byte + get_reconstructed_byte_from_top(bytes, scan_line_index, stride, byte_index)) & 0xff


reconstruct_byte_with_average_filter = (filtered_byte, bytes, scan_line_index, stride, byte_index) ->
  (filtered_byte + (
    get_reconstructed_byte_from_left(bytes, scan_line_index, stride, byte_index) +
    get_reconstructed_byte_from_top(bytes, scan_line_index, stride, byte_index)
  ) // 2) & 0xff


reconstruct_byte_with_Paeth_filter = (filtered_byte, bytes, scan_line_index, stride, byte_index) ->
  (filtered_byte + get_Paeth_predictor(
    get_reconstructed_byte_from_left(bytes, scan_line_index, stride, byte_index),
    get_reconstructed_byte_from_top(bytes, scan_line_index, stride, byte_index),
    get_reconstructed_byte_from_top_left(bytes, scan_line_index, stride, byte_index)
  )) & 0xff


reconstruct_methods =
  [0]: reconstruct_byte_with_none_filter
  [1]: reconstruct_byte_with_sub_filter
  [2]: reconstruct_byte_with_up_filter
  [3]: reconstruct_byte_with_average_filter
  [4]: reconstruct_byte_with_Paeth_filter


get_reconstructed_byte_from_left = (bytes, scan_line_index, stride, byte_index) ->
  if byte_index > bytes_per_pixel
    index = (scan_line_index - 1) * stride + byte_index - bytes_per_pixel
    bytes[index]
  else
    0


get_reconstructed_byte_from_top = (bytes, scan_line_index, stride, byte_index) ->
  if scan_line_index > 1
    index = (scan_line_index - 2) * stride + byte_index
    bytes[index]
  else
    0


get_reconstructed_byte_from_top_left = (bytes, scan_line_index, stride, byte_index) ->
  if scan_line_index > 1 and byte_index > bytes_per_pixel
    index = (scan_line_index - 2) * stride + byte_index - bytes_per_pixel
    bytes[index]
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


read_integer = (input, index) ->
  result = 0
  for i = index, index + 3
    byte = string.byte(input, i)
    result = (result << 8) + byte

  index + 4, result 


read_byte = (input, index) ->
  index + 1, string.byte(input, index)


write_byte = (output, byte, index) ->
  output[index] = byte
  
  index + 1


decode_png
