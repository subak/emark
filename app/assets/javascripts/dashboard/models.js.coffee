class Model.Blog extends Spine.Model
  @configure "Blog", "bid", "notebook", "title", "subtitle", "author"
  @extend Spine.Model.Ajax

class Model.Notebook extends Spine.Model
  @configure "Notebook", "notebookGuid", "notebookName", "available"
  @extend Spine.Model.Ajax
  @fromJSON: (notebooks)->
    for notebook in notebooks
      new @(id: notebook.notebookGuid, name: notebook.notebookName, available: notebook.available)

class Model.Sync extends Spine.Model
  @configure "Sync", "queued"
  @extend Spine.Model.Ajax
  @url: "/sync"

class Model.Session extends Spine.Model
  @configure "Session"
  @extend Spine.Model.Ajax
  @url: "/logout"
