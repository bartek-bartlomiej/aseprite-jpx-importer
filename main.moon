export init, exit

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
  arguments unless arguments.cancel


create_import_dialog = () ->
  with(Dialog("Import JPixel project"))
    on_confirm = () ->
      if .data.filename == ""
        app.alert({ title: "Error", text: "No file selected." })
      else
        \close!
      return

    --TODO: extract constants and reuse them in script 
    \file({ id: "filename", label: "JPixel project:", open: true, filetypes: { "jpx" } })
    \combobox({ id: "method", label: "PNG decoding method:", option: "decoder", options: { "decoder", "temporary file" } })
    \button({ text: "Convert", onclick: on_confirm })
    \button({ id: "cancel", text: "Cancel" })


export exit = (plugin) ->
  return
