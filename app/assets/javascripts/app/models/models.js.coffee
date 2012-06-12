class Model.Blog extends Spine.Model
  @configure "Blog", "bid", "notebook", "title", "subtitle", "author"
  @extend Spine.Model.Ajax

class Model.Notebook extends Spine.Model
  @configure "Notebook", "notebookGuid", "notebookName", "available"
  @extend    Spine.Model.Ajax
  @fromJSON: (object)->
    for notebook in object.notebooks
      new @(notebook)

class Model.Config extends Spine.Model
  @configure "Config", "title", "subtitle", "author"
  @extend Spine.Model.Ajax
  @url: "/config"
  validate: ->
    null

class Model.Sync extends Spine.Model
  @configure "Sync", "queued"
  @extend Spine.Model.Ajax
