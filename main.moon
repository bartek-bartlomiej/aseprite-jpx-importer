export init = (plugin) ->
  plugin\newCommand({
    id: "ImportJPX"
    title: "Import JPX file"
    group: "file_import"
    onclick: () -> print("TODO")
  })

  return


export exit = (plugin) ->
  return
