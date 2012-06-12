#= require config
#= require json2
#= require jquery
#= require spine
#= require spine/manager
#= require spine/ajax
#= require spine/route

#= require_tree ./lib
#= require_self
#= require_tree ./models
#= require_tree ./controllers
#= require_tree ./views

Model      = @Model      = {}
Controller = @Controller = {}

class App extends Spine.Controller
  constructor: ->
    @el = $("body")
    super

    class Pages extends Spine.Stack
      controllers:
        redirect: Controller.Redirect
        dashboard: Controller.Dashboard
        notebook: Controller.Notebook
        config:   Controller.Config
        sync:     Controller.Sync
        loading:  Controller.Loading
        error:    Controller.Error
      routes:
        "/":            "redirect"
        "/dashboard":   "dashboard"
        "/open":        "notebook"
        "/config/:bid": "config"
        "/sync/:bid":   "sync"

    Model.Config.bind   "ajaxError", @ajaxError
    Model.Notebook.bind "ajaxError", @ajaxError
    @append(@pages = new Pages)
    Spine.Route.setup(history: true)   

  ajaxError: =>
    alert("error")

window.App = App


