json_decode = dofile("json/decode.lua")

export init, exit

METHODS = { "decoder", "temporary file" }

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


try_parse_JSON = (content) -> try("parsing file", json_decode, content)


create_project_sprite = (filename, properties) ->
  { w: width, h: height } = properties

  with(Sprite(width, height))
    .filename = app.fs.fileTitle(filename)


set_up_project_sprite = (sprite, properties, method) ->
  app.transaction(() ->
    create_frames(sprite, properties)
    create_layers(sprite, properties)
    --TODO: create_cels(sprite, properties, method)
    --TODO: create_palette
  )


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


try = (description, f, ...) ->
  status, result = pcall(f, ...)

  if status
    result
  else
    app.alert("During #{description}, error occured: #{result}")
    nil


exit = (plugin) ->
  return
