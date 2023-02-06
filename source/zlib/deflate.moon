-- Copyright (c) 2023 Bartłomiej Stępień (refactor and MoonScript modifications)
-- Copyright (c) 2022 Penguin_Spy (naming and generating fixed codes)
-- Copyright (c) 2008-2011 David Manura (original implementation of deflate from compress.deflatelua)

local reverse_number
local memoize
sort = table.sort

create_huffman_table = (symbols_with_lengths) ->
  sort(symbols_with_lengths, (a, b) -> 
    a[2] == b[2] and a[1] < b[1] or a[2] < b[2]
  )

  symbols = {}

  node = symbols_with_lengths[1]
  symbol, length = node[1], node[2]
  minimal_length = length
  current_length = length

  code = 1 << length

  symbols[code] = symbol
  code = code + 1

  for i = 2, #symbols_with_lengths
    node = symbols_with_lengths[i]
    symbol, length = node[1], node[2]
    
    unless length == current_length
      code = code << (length - current_length)
      current_length = length
    
    symbols[code] = symbol
    code = code + 1

  get_first_code = memoize((bits) ->
    (1 << minimal_length) | reverse_number(bits, minimal_length)
  )

  (read) ->
    code = get_first_code[read(minimal_length)]
    while true
      symbol = symbols[code]
      return symbol if symbol

      code = (code << 1) | read(1)


reverse_number = (number, length) ->
  result = 0
  for _ = 1, length
    result = (result << 1) | (number & 1)
    number = number >> 1
  
  result


setmetatable = setmetatable

memoize = (f) ->
  lookup = {}
  return setmetatable(
    lookup,
    {
      __index: (key) =>
          value = f(key)
          lookup[key] = value
          
          value
    }
  )
  

local create_input_stream
local validate_zlib_header
local inflate
local validate_checksum
local assure_stream_completion  

zlib_deflate = (input, data_index, data_length) ->
  read, flush, is_complete = create_input_stream(input, data_index, data_length)
  output = {}

  validate_zlib_header(read)
  inflate(read, flush, output)
  validate_checksum(read, flush, output)
  assure_stream_completion(is_complete)

  output


validate_zlib_header = (read) ->
  compression_method = read(4)
  compression_info = read(4)
  -- CMF (Compresion Method and flags)
  cmf = compression_info << 4 + compression_method

  fcheck = read(5) -- FLaGs: FCHECK (check bits for CMF and FLG)
  fdict = read(1) -- FLaGs: FDICT (present dictionary)
  flevel = read(2) -- FLaGs: FLEVEL (compression level)
   -- FLaGs
  flg = flevel << 6 + fdict << 5 + fcheck

  unless compression_method == 8
    error("invalid compression method: #{compression_method}")

  unless compression_info <= 7 then
    error("invalid compression info: #{compression_info}")
  
  unless (cmf << 8 + flg) % 31 == 0
    error("invalid zlib header (bad fcheck sum)")

  if fdict == 1 then
    error("FDICT is not supported")


local create_output_stream
local parse_block

inflate = (read, flush, output) ->
  write, copy_previous = create_output_stream(output)

  is_final = false
  while not is_final
    is_final = parse_block(read, flush, write, copy_previous)


local copy_uncompressed_data
local decompress_using_fixed_tree
local decompress_using_dynamic_tree

parse_block = (read, flush, write, copy_previous) ->
  is_last = read(1) == 1
  block_type = read(2)

  switch block_type
    when 0
      copy_uncompressed_data(read, flush, write)
    when 1
      decompress_using_fixed_tree(read, write, copy_previous)
    when 2
      decompress_using_dynamic_tree(read, write, copy_previous)
    else
      error("Invalid DEFLATE block type (#{block_type})")

  is_last


copy_uncompressed_data = (read, flush, write) ->
  flush!
  length = read(16)
  inverse_length = read(16) ~ 0x0000ffff

  unless length == inverse_length
    error(" Invalid length for block type 0 (#{length} does not match #{inverse_length})")
  
  for _ = 1, length
    write(read(8))


fixed_literal_table = do
  size = 0
  literal_bit_lengths = {}
  for i = 0, 143
    size = size + 1
    literal_bit_lengths[size] = { i, 8 }
  for i = 144, 255
    size = size + 1
    literal_bit_lengths[size] = { i, 9 }
  for i = 256, 279
    size = size + 1
    literal_bit_lengths[size] = { i, 7 }
  for i = 280, 287
    size = size + 1
    literal_bit_lengths[size] = { i, 8 }
  
  create_huffman_table(literal_bit_lengths)


fixed_distance_table = do
  size = 0
  distance_bit_lengths = {}
  for i = 0, 31
    size = size + 1
    distance_bit_lengths[size] = { i, 5 }

  create_huffman_table(distance_bit_lengths)

local decompress_using_tree

decompress_using_fixed_tree = (read, write, copy_previous) ->
  decompress_using_tree(read, write, copy_previous, fixed_literal_table, fixed_distance_table)


local parse_huffman_tables

decompress_using_dynamic_tree = (read, write, copy_previous) ->
  literal_table, distance_table = parse_huffman_tables(read)
  decompress_using_tree(read, write, copy_previous, literal_table, distance_table)


local create_symbols_with_lengths

cl_symbols = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15}

parse_huffman_tables = (read) ->
  hlit, hdist, hclen = read(5), read(5), read(4)
  literal_codes_count = hlit + 257
  distance_codes_count = hdist + 1

  cl_symbols_with_lengths = {}
  size = 0
  for i = 1, hclen + 4
    length = read(3)
    unless length == 0
      size = size + 1
      cl_symbols_with_lengths[size] = { cl_symbols[i], length }
    
  cl_table = create_huffman_table(cl_symbols_with_lengths)

  literal_table = create_huffman_table(
    create_symbols_with_lengths(read, cl_table, literal_codes_count)
  )
  distance_table = create_huffman_table(
    create_symbols_with_lengths(read, cl_table, distance_codes_count)
  )

  literal_table, distance_table


create_symbols_with_lengths = (read, read_table, codes_count) ->
  symbols_with_lengths = {}
  size, symbol = 0, 0
  local length

  while symbol < codes_count
    codelen = read_table(read)
    
    local repeat_count
    if codelen <= 15
      repeat_count = 1
      length = codelen
    elseif codelen == 16
      repeat_count = 3 + read(2)
      -- length unchanged
    elseif codelen == 17
      repeat_count = 3 + read(3)
      length = 0
    elseif codelen == 18
      repeat_count = 11 + read(7)
      length = 0

    for _ = 1, repeat_count
      unless length == 0
        size = size + 1
        symbols_with_lengths[size] = { symbol, length }
      
      symbol = symbol + 1
  
  symbols_with_lengths


local get_length, get_distance

decompress_using_tree = (read, write, copy_previous, read_literal_table, read_distance_table) ->
  local symbol
  while symbol ~= 256
    symbol = read_literal_table(read)
    if symbol < 256
      write(symbol)
    elseif symbol > 256
      length = get_length(read, symbol)
      distance = get_distance(read, read_distance_table)
      copy_previous(distance, length)
    

local length_codes

get_length = (read, symbol) ->
  code = length_codes[symbol]
  length, extra_bits_count = code[1], code[2]
  if extra_bits_count > 0
    length = length + read(extra_bits_count)
  
  length


local distance_codes

get_distance = (read, read_distance_table) ->
  symbol = read_distance_table(read)
  code = distance_codes[symbol]
  distance, extra_bits_count = code[1], code[2]
  if extra_bits_count > 0
    distance = distance + read(extra_bits_count)
  
  distance


do
  local symbol, bits, base_value
  create_codes = (codes, count) ->
    for _ = 1, count
      codes[symbol] = { base_value, bits }
      base_value = base_value + (1 << bits)
      symbol = symbol + 1
    
    bits = bits + 1
  

  length_codes = {}
  symbol, bits, base_value = 257, 0, 3
  create_codes(length_codes, 8)
  for _ = 1, 5
    create_codes(length_codes, 4) 
  length_codes[285] = { 258, 0 }

  distance_codes = {}
  symbol, bits, base_value = 0, 0, 1
  create_codes(distance_codes, 4)
  for _ = 1, 13 
    create_codes(distance_codes, 2)


local parse_checksum
local calculate_checksum

validate_checksum = (read, flush, output) ->
  expected_checksum = parse_checksum(read, flush)
  checksum = calculate_checksum(output)

  unless checksum == expected_checksum
    error("invalid compressed data - checksum does not match")


parse_checksum = (read, flush) ->
  flush!

  checksum = 0
  for _ = 1, 4
    checksum = (checksum << 8) | read(8)

  checksum



calculate_checksum = (buffer) ->
  checksum = 1
  for i = 1, #buffer do
    high = checksum >> 16
    low = checksum & 0xffff

    a = (low + buffer[i]) % 65521
    b = (high + a) % 65521

    checksum = (b << 16) | a
  
  checksum


assure_stream_completion = (is_complete) ->
  unless is_complete()
    error("unexpected trailing garbage")


to_byte = string.byte

create_input_stream = (input, data_index, data_length) ->
  index = data_index
  limit = data_index + data_length - 1

  bits_buffer = 0
  bits_buffer_size = 0

  flush_to_full_byte = () ->
    bits_buffer = 0
    bits_buffer_size = 0
  
  read = (n) ->
    while bits_buffer_size < n do
      unless index <= limit
        error("unexpected EOF while decompressing")
      
      bits_buffer = bits_buffer + (to_byte(input, index) << bits_buffer_size)
      bits_buffer_size = bits_buffer_size + 8
      index = index + 1
    

    local bits
    switch n
      when 0
        bits = 0
      when 32
        bits = bits_buffer
        bits_buffer = 0
        bits_buffer_size = 0
      else
        bits = bits_buffer & (0xffffffff >> (32 - n))
        bits_buffer = bits_buffer >> n
        bits_buffer_size = bits_buffer_size - n
    
    bits
  

  is_complete = () -> not (index <= limit)
  
  read, flush_to_full_byte, is_complete


create_output_stream = (output) ->
  index = 1

  write = (byte) ->
    output[index] = byte
    index = index + 1
  
  copy_previous = (offset, n) ->
    previous_index = index - offset
    unless output[previous_index]
      error("invalid distance")
    
    for _ = 1, n
      output[index] = output[previous_index]
      index = index + 1
      previous_index = previous_index + 1

  write, copy_previous


zlib_deflate
