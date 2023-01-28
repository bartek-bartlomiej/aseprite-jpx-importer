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


exit = (plugin) ->
  return
