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
        redirect:  Controller.Redirect
        dashboard: Controller.Dashboard
        open:      Controller.Open
        config:    Controller.Config
        sync:      Controller.Sync
        loading:   Controller.Loading
        error:     Controller.Error
      routes:
        "/":            "redirect"
        "/dashboard":   "dashboard"
        "/open":        "open"
        "/config/:bid": "config"
        "/sync/:bid":   "sync"

    Model.Notebook.bind "ajaxError", @ajaxError
    @append(@pages = new Pages)
    Spine.Route.setup(history: true)   

  ajaxError: =>
    alert("error")

window.App = App

jQuery.validator.messages = 
  required:    "required"
  remote:      "remote"
  email:       "email"
  url:         "url"
  date:        "date"
  dateISO:     "dateISO"
  number:      "number"
  digits:      "digits"
  creditcard:  "creditcard"
  equalTo:     "equalto"
  maxlength:   "maxlength"
  minlength:   "minlength"
  rangelength: "rangelength"
  range:       "range"
  max:         "max"
  min:         "min"

jQuery.validator.setDefaults
  invalidHandler: (event, validator)->
    $("[id^='invalid-']", event.currentTarget).addClass "hidden"
    for obj in validator.errorList
      context = $(obj.element).parents(".control-group")[0]
      if context
        console.log "#invalid-#{obj.element.name}-with-#{obj.message}"
        $("#invalid-#{obj.element.name}-with-#{obj.message}").removeClass "hidden"
      $(context).addClass "error"
  showErrors: -> null

jQuery.validator.addMethod "regex", (value, element, params)->
  console.log this
  false
, "regex"