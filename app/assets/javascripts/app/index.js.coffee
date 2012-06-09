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

Model = {}

class Model.Blog extends Spine.Model
  @configure "Blog", "bid", "title", "subtitle"
  @extend Spine.Model.Ajax
  @url = "/dashboard"


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


      "/dashboard": ->
        Model.Blog.bind "refresh", (model)->
          console.log model
#          console.log Model.Blog.first()
#          Model.Blog.each (model), ->
#            console.log "model"

        
        Model.Blog.fetch()
        

      "/config/:bid": (params)->
        console.log params.bid

    # Initialize controllers:
    #  @append(@items = new App.Items)
    #  ...

    Spine.Route.setup(history: true)

window.App = App
