#= require json2
#= require jquery
#= require spine
#= require spine/manager
#= require spine/ajax
#= require spine/route

#= require ./config
#= require_tree ./dashboard/lib
#= require ./dashboard/before
#= require_tree ./dashboard/models
#= require_tree ./dashboard/controllers
#= require_tree ./dashboard/views
#= require_self

class Manager.Pages extends Spine.Stack
  controllers:
    token:     Controller.Token
    dashboard: Controller.Dashboard
    open:      Controller.Open
    config:    Controller.Config
    close:     Controller.Close
    sync:      Controller.Sync
    logout:    Controller.Logout
    loading:   Controller.Loading
    error:     Controller.Error
  routes:
    "/":            "token"
    "/dashboard":   "dashboard"
    "/open":        "open"
    "/close/:bid":  "close"
    "/config/:bid": "config"
    "/sync/:bid":   "sync"
    "/logout":      "logout"

class App extends Spine.Controller
  config: Emark.Config
  constructor: ->       
    @el = $("body")
    super

    Model.Blog.bind     "ajaxError", @ajaxError
    Model.Notebook.bind "ajaxError", @ajaxError
    Model.Sync.bind     "ajaxError", @ajaxError
    Model.Session.bind  "ajaxError", @ajaxError

    @append(@pages = new Manager.Pages)

    for key, value of @pages.controllers
      obj = @pages[key]
      obj.bind "forbidden", @forbidden
      obj.bind "fatal",     @fatal
      obj.bind "loading",   @loading
      obj.bind "loaded",    @loaded

    Spine.Route.setup(history: true)   

  loading:   => @pages.loading.trigger "show"
  loaded:    => @pages.loading.trigger "hide"
  forbidden: => @pages.error.trigger   "show"
  fatal:     => @pages.error.trigger   "show"

  ajaxError: (record, xhr, settings, error)=>
    # console.log record
    # console.log xhr
    console.log settings
    console.log error
    @pages.error.trigger "show"
  events:
    "click a[href$='/logout']": "logout"
  logout: (event)->
    event.preventDefault()
    @pages.loading.trigger "show"
    @navigate "/logout"

window.App = App
