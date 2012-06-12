#= require config
#= require json2
#= require jquery
#= require jquery.cookie
#= require spine
#= require spine/manager
#= require spine/ajax
#= require spine/route

#= require_tree ./lib
#= require_self
#= require_tree ./models
#= require_tree ./controllers
#= require_tree ./views

Model      = {}
Controller = {}

class Model.Blog extends Spine.Model
  @configure "Blog", "bid", "title", "subtitle", "author"
  @extend Spine.Model.Ajax

class Model.Notebook extends Spine.Model
  @configure "Notebook", "notebookGuid", "notebookName", "available"
  @extend    Spine.Model.Ajax
  @fromJSON: (object)->
    for notebook in object.notebooks
      new @(notebook)
  @url: "/open"

class Controller.Blog extends Spine.Controller
  events:
    "click #open-blog > a":     "navigate_to_open"
    "click a[class~='config']": "navigate_to_config"
  constructor: ->
    @config = Emark.config
    @el = $("#index-container")
    super

    @active ->
      Model.Blog.url = "/dashboard"
      Model.Blog.fromJSON = (object)->
        for blog in object.blogs
          new @(blog)
      Model.Blog.fetch()
      Model.Blog.one "refresh", @render
  render: =>
    @stack.loading.trigger "hide"
    @blogs = Model.Blog.all()
    @el.empty()
    @html @view("blogs")(@)
  navigate_to_open: =>
    event.preventDefault()
    @stack.loading.trigger "show"
    @navigate "/open"
  navigate_to_config: (event)=>
    event.preventDefault()
    @stack.loading.trigger "show"
    @navigate $(event.currentTarget).attr("href")

class Controller.Notebook extends Spine.Controller
  constructor: ->
    @config = Emark.config
    @el = $("#publish-container")
    super
    @active ->
      Model.Notebook.one "refresh", @render
      Model.Notebook.fetch()
  render: =>
    @stack.loading.trigger "hide"
    @notebooks = Model.Notebook.all()
    @el.empty()
    @html @view("notebooks")(@)
    @el.modal "show"
  events:
    "hidden" : "hidden"
    "submit form" : "submit"
  submit: (event)->
    event.preventDefault()
  hidden: ->
    @stack.loading.trigger "show"
    @navigate "/dashboard"

class Model.Config extends Spine.Model
  @configure "Config", "title", "subtitle", "author"
  @extend Spine.Model.Ajax
  @url: "/config"
  validate: ->
    null

class Controller.Config extends Spine.Controller
  constructor: ->
    @config = Emark.Config
    @el = $("<div class='modal fade'></div>")
    super
    @active (params)->
      Model.Config.url = "/config/#{params.bid}"
      Model.Config.fetch()
      Model.Config.one  "refresh",   @render
      Model.Config.bind "error",     @validationError
  render: =>
    @stack.loading.trigger "hide"
    @blog = Model.Config.first()
    @el.empty()
    @html @view("config")(@)
    @el.modal "show"
  validationError: (rec, msg)=>
    console.log "validationErrorだよ"
  updated: =>
    @navigate "/dashboard"
  events:
    "hidden":            "hidden"
    "click .nav-tabs a": "switch_tab"
    "submit form":       "submit"
  hidden: ->
    @stack.loading.trigger "show"
    @navigate "/dashboard"
  switch_tab: (event)->
    event.preventDefault()
    $(event.currentTarget).tab("show")
  submit: (event)->
    event.preventDefault()
    Model.Config.url = "/config"
    blog = @blog.fromForm(event.currentTarget)
    blog.bind "ajaxSuccess", @updated
    blog.save()
    @el.modal "hide"
    @stack.loading.trigger "show"


class Controller.Redirect extends Spine.Controller
  constructor: ->
    super
    @active ->
      $.ajax
        url:      "/"
        data:     location.search.substr 1
        dataType: 'text'
      .fail =>
        @trigger 'reject'
      .done ( redirect ) =>
        location.href = redirect   


class Controller.Loading extends Spine.Controller
  constructor: ->
    @el = @view("loading")()
    @bind "hide", ->
      @el.fadeOut()
    @bind "show", ->
      @el.show()
    super


class Pages extends Spine.Stack
  controllers:
    redirect: Controller.Redirect
    blog:     Controller.Blog
    notebook: Controller.Notebook
    config:   Controller.Config
    loading:  Controller.Loading
  routes:
    "/dashboard":  "blog"
    "/open":       "notebook"
    "/":           "redirect"
    "/config/:bid": "config"


class App extends Spine.Controller
  constructor: ->
    @el = $("body")
    super

    Model.Config.bind   "ajaxError", @ajaxError
    Model.Notebook.bind "ajaxError", @ajaxError
    @append(@pages = new Pages)
    Spine.Route.setup(history: true)   

  ajaxError: =>
    alert("error")

window.App = App
