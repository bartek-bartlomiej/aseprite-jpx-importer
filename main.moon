export init, exit

ID = {
  filename: "filename"
  method: "method"
  cancel: "cancel"
}

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

  -- TODO: next steps
  
  return


request_arguments = () ->
  dialog = with create_import_dialog!
    \show!
  arguments = dialog.data
  
  arguments unless arguments[ID.cancel]


create_import_dialog = () ->
  with(Dialog("Import JPixel project"))
    on_confirm = () ->
      if .data[ID.filename] == ""
        app.alert({ title: "Error", text: "No file selected." })
      else
        \close!
      return

    \file({ id: ID.filename, label: "JPixel project:", open: true, filetypes: { "jpx" } })
    \combobox({ id: ID.method, label: "PNG decoding method:", option: METHODS[1], options: METHODS })
    \button({ text: "Convert", onclick: on_confirm })
    \button({ id: ID.cancel, text: "Cancel" })


exit = (plugin) ->
  return
