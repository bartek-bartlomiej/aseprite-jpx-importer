-- Copyright (c) 2023 Bartłomiej Stępień (MoonScript modifications)
-- Copyright (c) 2013 aiq (original version)

get_byte = string.byte

EQUALS_SIGN = get_byte("=")

local *

lookup = do
  base64_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  base64_length = 6

  to_bits = (number, length) ->
    bits = {}
    for i = length, 1, -1
      remainder = math.fmod(number, 2)
      number = math.floor((number - remainder) / 2)

      bits[i] = remainder
    
    bits
  
  { get_byte(base64_alphabet, i), to_bits(i - 1, base64_length) for i = 1, #base64_alphabet }


decode = (input) ->
  bits = decode_bits(input)
  bytes = convert_bits_to_bytes(bits)

  string.char(table.unpack(bytes))


decode_bits = (input) ->
  size = 0
  result = {}
  
  for i = 1, #input
    byte = get_byte(input, i)
    continue if byte == EQUALS_SIGN
    
    bits = lookup[byte]
    
    unless bits
      error("unexpected character at position #{i}: '#{string.char(byte)}'")
    
    result[size + j] = bits[j] for j = 1, #bits
    size += #bits

  result


convert_bits_to_bytes = (bits) ->
  size = #bits
  
  bytes = for i = 1, size - size % 8, 8
    byte = 0
    byte = byte * 2 + bit for bit in *bits[i, i + 7]
    
    byte

  bytes


decode
