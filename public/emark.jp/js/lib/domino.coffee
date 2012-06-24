###
# Name:    Domino the MVC Framework
# Version: 0.1.1
# Author:  Takahashi Hiroyuki
# License: GPL Version 2
# @depend: jQuery
###

`
if ('undefined' == typeof(Domino)) {
  Domino = {}
}
`

##
# Model
class Domino.Model
  binds: null
  initialize: ->

  constructor: (@json) ->
    @binds = {}
    @initialize()

  select: ->
    return @json

  set: ( json ) ->
    @json = json
    @transform()
    @trigger 'change', @select()
    @trigger 'refresh', @select()

  toJson: ->
    return @json
  transform: ->
    return @
  bind: (event, handler) ->
    @binds[event] = [] if !@binds[event]?
    @binds[event].push handler
  trigger: ( event, data=null ) ->
    if @binds[event]?
      for handler in @binds[event]
        handler(data)
  unbind: ->
    @binds = {}

##
# View
class Domino.View
  subject: null
  el:      null
  binds:   null
  build:   ->
  events:  ->

  constructor: ->
    @binds = {}
    @initialize()
    @events()

  initialize: -> @el = jQuery(@subject)
  show:       -> @el.show()
  hide:       -> @el.hide()

  render:  ->
    @trigger 'render_before'
    @show()
    @trigger 'render_after'

  reset:   ->
    @trigger 'reset_before'
    @hide()
    @trigger 'reset_after'

  bind: ( event, handler ) ->
    @binds[event] = [] if !@binds[event]?
    @binds[event].push handler

  trigger: ( event, data=null ) ->
    if @binds[event]?
      for handler in @binds[event]
        #handler.apply(data)
        handler(data)

  unbind: ->
    @binds = {}

class Domino.View.Template extends Domino.View
  initialize: ->
    super()
    @tpl = new Subak.Template jQuery(@subject).get(0), resetable:true

  build: ( data={}, namespace=null )->
    @trigger 'build_before'
    @tpl.load data, namespace
    @trigger 'build_after'

  render: ->
    @trigger 'render_before'
    @tpl.close()
    @show()
    @trigger 'render_after'

  reset: ->
    @trigger 'reset_before'
    @tpl.reset()
    @el = jQuery(@subject)
    @hide()
    @trigger 'reset_after'

##
# Controller
class Domino.Controller
  @popstate: ( process )->
    run = ->
      jQuery(window).on 'popstate', ->
        process()
      jQuery(window).trigger 'popstate'
    
    if history.pushState?
      init = ->
        jQuery(window).off 'popstate', init
        run()
      jQuery(window).on 'popstate', init
    else
      run()

  initial:  null
  routes:   null
  procs:    null
  binds:    null
  views:    null
  models:   null
  bindings: null

  constructor: ->
    @initial = true
    @routes = []
    @procs  = []
    @binds  = {}
    @views  = []
    @models = []
    @bindings = []

  route: (route, proc)->
    @routes.push route
    @procs.push proc

  reroute: (route, push=true)->
    if history.pushState? and !route.match(/^https?/)
      @run route, true, push
    else
      window.open route, "_blank"

  bind: ( event, handler ) ->
    @binds[event] = [] if !@binds[event]?
    @binds[event].push handler

  trigger: ( event, data=null ) ->
    if @binds[event]?
      for handler in @binds[event]
        handler(data)

  binding: ( binding=-> ) ->
    @bindings.push ->
      bindings = binding.apply(@)
      for event, handler of bindings
        @bind event, handler

  view: ( name )->
    @views[name]

  model: ( name )->
    @models[name]

  set_model: ( name, Model, bindings=-> )->
    @bindings.push ->
      model = new Model
      bindings = bindings.apply(@)
      for event, handler of bindings      
        model.bind event, handler
      @models[name] = model

  set_view: ( name, View, bindings=-> )->
    @bindings.push ->
      view = new View
      bindings = bindings.apply(@)
      for event, handler of bindings
        view.bind event, handler
      @views[name] = view    

  run: ( path, state=false, push=true)->

    onerror = ( event ) =>
      jQuery(window).unbind 'error'
      @trigger 'reject'
      console.log event
      alert event
    jQuery(window).bind 'error', onerror

    if @initial
      for binding in @bindings
        binding.apply(@)
      @trigger "binding_after"
      @initial = false

    found = false
    for route, i in @routes
      if not (route instanceof RegExp)
        if route == path
          # routeが見つかった
          if state
            if push
              history.pushState null, null, path
            else
              history.replaceState null, null, path
                        
          @trigger 'before_run'
          @trigger 'before'
          @trigger 'started'
          @procs[i].apply @
          found = true
          break

        re = route.replace /\/:[^/]+/g, '/([^/]+)'
        continue if re == route

        re    = re.replace /\//g, '\\/'
        re    = "^#{re}$"
        route = RegExp(re, 'g')

      if route.exec path
        # routeが見つかった
        if state
          if push
            history.pushState null, null, path
          else
            history.replaceState null, null, path

        captures = []
        n = 1
        while capture = RegExp['$' + n]
          captures.push capture
          n++
        @trigger 'before_run'
        @trigger 'before'
        @trigger 'started'
        @procs[i].apply(this, captures)
        found = true
        break;

    # 403
    location.href = path if !found
    #throw 'not found' if !found
