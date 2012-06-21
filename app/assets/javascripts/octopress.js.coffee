#= require jquery
#= require jquery_ujs
#= require hamlcoffee
#= require spine
#= require spine/manager
#= require spine/ajax
#= require spine/route
#= require_tree ./octopress
#= require_self

Spine.Controller.include
  view: (name) ->
    JST["octopress/views/layouts/#{name}"] || -> "not found"
  include: (name) ->
    JST["octopress/views/includes/#{name}"] || -> "not found"

class MetaEntry extends Spine.Model
  @extend Spine.Model.Ajax
  @url: "/index.json"

class Post extends Spine.Controller
  active: (params={})->
    @render()
  render: ->
    @el.remove()
    @el = @view("post")(@)
    $("#main > div").replaceWith @el

class Archive extends Spine.Controller
  active: ->
    @render()

class App extends Spine.Controller
  constructor: ->
    @pages = {
      post: new Post
    }

    MetaEntry.one "refresh", -> console.log("huga")
    MetaEntry.fetch()

    @routes
      "/":           -> @pages.post.active()
      "/page/:page": (params)-> @pages.post.active(params)
      "/archives":   ->
      "/:eid":       (params)-> @pages.post.active(params)

    Spine.Route.setup history: true

new App