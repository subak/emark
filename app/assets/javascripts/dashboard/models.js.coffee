class Model.Blog extends Spine.Model
  @configure "Blog", "bid", "notebook", "title", "subtitle", "author", "about_me", "twitter_user", "disqus_short_name", "recent_posts", "paginate", "excerpt_count"
  @extend Spine.Model.Ajax
  @fromJSON: (blogs)->
    for blog in blogs
      blog["id"] = blog["bid"]
      new @(blog)

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
