Spine.Controller.include
  view: (name) ->
    console.log name
    JST["app/views/#{name}"]