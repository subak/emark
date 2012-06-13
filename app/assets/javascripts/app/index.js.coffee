#= require config
#= require json2
#= require jquery
#= require spine
#= require spine/manager
#= require spine/ajax
#= require spine/route

#= require config

#= require_tree ./lib
#= require_self
#= require_tree ./models
#= require_tree ./controllers
#= require_tree ./views

Model      = @Model      = {}
Controller = @Controller = {}
Manager    = @Manager    = {}

class App extends Spine.Controller
  config: Emark.Config
  constructor: ->
    @el = $("#app")
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