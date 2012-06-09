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

class Model.Config extends Spine.Model
  @configure "Config", "bid", "title", "subtitle"
  @extend Spine.Model.Ajax

class Model.Notebook extends Spine.Model
  @configure "Notebook", "notebookGuid", "notebookName", "available"
  @extend    Spine.Model.Ajax
  @fromJSON: (object)->
    for notebook in object.notebooks
      new @(notebook)
  @url: "/open"

class Controller.Notebook extends Spine.Controller
  constructor: ->
    @el = $("#publish-container")
    super
    Model.Notebook.one "refresh", @render
  events:
    "shown" : "shown"
    "submit form" : "submit"
  submit: (event)->
    event.preventDefault()

  render: =>
    console.log @hoge
    @notebooks = Model.Notebook.all()
    @html @view("notebooks")(@)
    @el.modal "show"

class App extends Spine.Controller
  constructor: ->
    super

    @bind "reject", ->
      alert "error"

    @routes
      "/": ->
        $.ajax
          url:      "/"
          data:     location.search.substr 1
          dataType: 'text'
        .fail =>
          @trigger 'reject'
        .done ( redirect ) =>
          location.href = redirect

      "/open": ->
        $ -> new Controller.Notebook()
        Model.Notebook.fetch()

      "/dashboard": ->
        Model.Config.bind "refresh", (model)->
          console.log model
#          console.log Model.Blog.first()
#          Model.Blog.each (model), ->
#            console.log "model"


        Model.Config.url = "/dashboard"
        Model.Config.fromJSON = (object)->
          for blog in object.blogs
            new @(blog)

        Model.Config.fetch()
        

      "/config/:bid": (params)->
        console.log params.bid

    # Initialize controllers:
    #  @append(@items = new App.Items)
    #  ...

    Spine.Route.setup(history: true)

window.App = App
