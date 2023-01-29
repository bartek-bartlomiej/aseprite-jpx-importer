json_decode = dofile("json-decode.lua")

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

  data = get_project_data(arguments.filename)
  return unless data

  print("continue")
  
  -- TODO: next steps
  
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


get_project_data = (filename) ->
  content = try_read_file_content(filename)
  return unless content

  try_parse_JSON(content)


try_read_file_content = (filename) -> try("reading file", read_file_content, filename)


read_file_content = (filename) ->
  local content
  with(io.open(filename, "r"))
    content = \read("a")
    \close!
  
  content


try_parse_JSON = (content) -> try("parsing file", json_decode, content)


try = (description, f, ...) ->
  status, result = pcall(f, ...)

  if status
    result
  else
    app.alert("During #{description}, error occured: #{result}")
    nil


exit = (plugin) ->
  return
