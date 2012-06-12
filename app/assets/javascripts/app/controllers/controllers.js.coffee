class Controller.Dashboard extends Spine.Controller
  events:
    "click #open-blog > a":     "navigate_to_open"
    "click a[class~='config']": "navigate_to_config"
    "click a[class~='sync']":   "sync"
  constructor: ->
    @config = Emark.config
    super
    @active ->
      if 1 <= Model.Blog.count()
        @delay((=> @render()), 500)
      else
        Model.Blog.fetch()
        Model.Blog.one "refresh", @render
  render: =>
    @stack.loading.trigger "hide"
    @blogs = Model.Blog.all()
    @replace @view("blogs")(@)
  navigate_to_open: =>
    event.preventDefault()
    @stack.loading.trigger "show"
    @navigate "/open"
  navigate_to_config: (event)=>
    event.preventDefault()
    @stack.loading.trigger "show"
    @navigate $(event.currentTarget).attr("href")
  sync: (event)=>
    event.preventDefault()
    @stack.loading.trigger "show"
    @navigate $(event.currentTarget).attr("href")


class Controller.Config extends Spine.Controller
  constructor: ->
    @config = Emark.Config
    super
    @active (params)->
      @bid = params.bid
      if Model.Blog.findByAttribute("bid", @bid)
        @delay((=> @render()), 500)
      else
        Model.Blog.fetch()
        Model.Blog.one "refresh", @render
  render: =>
    @blog = Model.Blog.findByAttribute("bid", @bid)
    @stack.loading.trigger "hide"
    @replace @view("config")(@)
    @el.modal "show"
  validationError: (rec, msg)=>
    console.log "validationErrorだよ"

  updated: =>
    @stack.loading.trigger "show"
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


class Controller.Open extends Spine.Controller
  constructor: ->
    @config = Emark.config
    super
    @active ->
      if 1 <= Model.Notebook.count()
        @delay((-> @render()), 500)
      else
        Model.Notebook.one "refresh", @render
        Model.Notebook.fetch()
  render: =>
    @stack.loading.trigger "hide"
    @notebooks = Model.Notebook.all()
    @replace @view("open")(@)
    @el.modal "show"
  events:
    "hidden":      "hidden"
    "submit form": "submit"
  hidden: ->
    @stack.loading.trigger "show"
    @navigate "/dashboard"
  submit: (event)->
    event.preventDefault()


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


class Controller.Sync extends Spine.Controller
  constructor: ->
    @model = {}
    @el    = @view("sync")(@)
    @active (params)->
      Model.Sync.url = "/sync/#{params.bid}"
      @model = Model.Sync.create()
      @model.one "ajaxSuccess", @render
    super
  render: =>
    console.log typeof @model.queued
    @stack.loading.trigger "hide"
    @replace @view("sync")(@)
    @el.modal "show"
  events:
    "hidden": "hidden"
  hidden: =>
    @stack.loading.trigger "show"
    @navigate "/dashboard"


class Controller.Loading extends Spine.Controller
  constructor: ->
    @el = @view("loading")()
    @bind "hide", ->
      @el.fadeOut()
    @bind "show", ->
      @el.show()
    super


class Controller.Error extends Spine.Controller
  constructor: ->
    @el = @view("error")()
    @bind "show", ->
      @el.show()
    super