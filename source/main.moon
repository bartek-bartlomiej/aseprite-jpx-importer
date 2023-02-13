decode_json = dofile("json-decode.lua")
decode_base64 = dofile("base64-decode.lua")
decode_png = dofile("png-decode.lua")

export init, exit

DECODE_METHOD = "decoder"
TEMPORARY_FILE_METHOD = "temporary file"

METHODS = { 
  DECODE_METHOD, 
  TEMPORARY_FILE_METHOD 
}

local *


init = (plugin) ->
  plugin\newCommand({
    id: "ImportJPX"
    title: "Import JPX file"
    group: "file_import"
    onclick: do_import
  })

  return


do_import = () ->  
  arguments = request_arguments!
  return unless arguments

  properties = get_project_properties(arguments.filename)
  return unless properties

  -- TODO: validate_properties

  sprite = create_project_sprite(arguments.filename, properties)
  return unless sprite

  set_up_project_sprite(sprite, properties, arguments.method)
  
  return


request_arguments = () ->
  ID = { filename: "f", method: "m" }

  confirmed = false

  dialog = with(Dialog("Import JPixel project"))
    \file({ id: ID.filename, label: "JPixel project:", open: true, filetypes: { "jpx" } })
    \combobox({ id: ID.method, label: "PNG decoding method:", option: METHODS[1], options: METHODS })
    \button({ text: "Import", onclick: () ->
      if .data[ID.filename] == ""
        app.alert({ title: "Error", text: "No file selected." })
      else
        confirmed = true
        \close!
      return
    })
    \button({ text: "Cancel" })
    \show!
  
  data = dialog.data
  { filename: data[ID.filename], method: data[ID.method] } if confirmed


get_project_properties = (filename) ->
  content = try_read_file_content(filename)
  return unless content

  try_parse_JSON(content)


try_read_file_content = (filename) -> try("reading file", read_file_content, filename)


read_file_content = (filename) ->
  local content
  with io.open(filename, "r")
    content = \read("a")
    \close!
  
  content


try_parse_JSON = (content) -> try("parsing file", decode_json, content)


create_project_sprite = (filename, properties) ->
  { w: width, h: height } = properties

  with(Sprite(width, height))
    .filename = app.fs.fileTitle(filename)


set_up_project_sprite = (sprite, properties, method) ->
  app.transaction(() ->
    create_image = creating_image_methods[method]

    create_frames(sprite, properties)
    create_layers(sprite, properties)
    create_cels(sprite, properties, create_image)
    --TODO: create_palette
  )


creating_image_methods =
  [DECODE_METHOD]: (encoded_data) ->
    png_image = decode_png(decode_data(encoded_data))

    with Image(png_image.width, png_image.height)
      .bytes = string.char(table.unpack(png_image.bytes, 1, png_image.bytes.n))

  [TEMPORARY_FILE_METHOD]: (encoded_data) ->
    filename = app.fs.joinPath(app.fs.tempPath, 'aseprite-convert-jpx.png')
    with io.open(filename, "w")
      \write(decode_data(encoded_data))
      \flush!
      \close!

    Image({ fromFile: filename })


DATA_HEADER_LENGTH = string.len("data:image/png;base64,")

decode_data = (encoded_data) ->
  decode_base64(string.sub(encoded_data, DATA_HEADER_LENGTH + 1))


create_frames = (sprite, properties) ->
  { :default_speed, frames: frames_properties } = properties
  for i = 1, #frames_properties
    with sprite\newEmptyFrame(i)
      .duration = frames_properties[i].speed or default_speed
  
  sprite\deleteFrame(#(sprite.frames)) -- initial frame was moved to the end


EMPTY_NAME = ""

create_layers = (sprite, properties) ->
  { :layers } = sprite
  initial_layers_count = #layers

  for i = 1, initial_layers_count
    layers[i].name = EMPTY_NAME

  for _ = 1, count_layers(properties) - initial_layers_count
    with sprite\newLayer!
      .name = EMPTY_NAME


count_layers = (properties) ->
  { frames: frames_properties } = properties
  
  count = 0
  for frame_properties in *frames_properties
    count = math.max(count, #(frame_properties.layers))

  count


create_cels = (sprite, properties, create_image) ->
  for i = 1, #(properties.frames)
    frame = sprite.frames[i]
    frame_properties = properties.frames[i]
    frame_layers_count = #(frame_properties.layers)

    -- in JPixel files, order of layers is reversed
    for j = frame_layers_count, 1, -1
      layer = sprite.layers[frame_layers_count - j + 1]
      layer_properties = frame_properties.layers[j]

      colors_image = create_image(layer_properties.color)
      alpha_image = create_image(layer_properties.alpha)

      with sprite\newCel(layer, frame)
       for pixel in .image\pixels!
         { :x, :y } = pixel
         pixel(get_color(x, y, colors_image, alpha_image))

      --app.refresh!

  
get_color = do
  color = app.pixelColor
  r = color.rgbaR
  g = color.rgbaG
  b = color.rgbaB
  a = color.rgbaR
  create = color.rgba

  (x, y, colors, alpha) ->
    colors_value = colors\getPixel(x, y)
    alpha_value = alpha\getPixel(x, y)

    create(
      r(colors_value),
      g(colors_value),
      b(colors_value),
      a(alpha_value)
    )


try = (description, f, ...) ->
  status, result = pcall(f, ...)

  if status
    result
  else
    app.alert("During #{description}, error occured: #{result}")
    nil


exit = (plugin) ->
  return
