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
    @stack.error.trigger "show" if not @blog
    @stack.loading.trigger "hide"
    @replace @view("config")(@)
    @el.modal "show"

  validationError: (rec, msg)=>
    console.log "validationErrorだよ"

  events:
    "click .nav-tabs a": "switch_tab"
    "hidden":            "hidden"
    "submit form":       "submit"

  switch_tab: (event)->
    event.preventDefault()
    $(event.currentTarget).tab("show")

  hidden: ->
    @stack.loading.trigger "show"
    @navigate "/dashboard"

  submit: (event)->
    event.preventDefault()
    blog = @blog.fromForm(event.currentTarget)
    blog.bind "ajaxSuccess", @updated
    blog.save()
    @el.modal "hide"
    @stack.loading.trigger "show"

  updated: =>
    @navigate "/dashboard"


class Controller.Open extends Spine.Controller
  constructor: ->
    @config = Emark.config
    super
    @active ->
      Model.Notebook.one "refresh", @render
      Model.Notebook.fetch()
  render: =>
    @stack.loading.trigger "hide"
    @notebooks = Model.Notebook.all()
    @replace @view("open")(@)
    @el.modal "show"
  events:
    "hidden":      "hidden"
    "shown":       "shown"
  hidden: ->
    @stack.loading.trigger "show"
    @navigate "/dashboard"

  new_blog: (form)=>
    blog = Model.Blog.fromForm(form)
    blog.one "ajaxSuccess", @updated
    @el.modal "hide"
    blog.save()

  updated: =>
    @stack.loading.trigger "show"
    @navigate "/dashboard"

  shown: ->
    @$("form").submit (event)->
      subdomain = $("input[name='subdomain']", this).val()
      domain    = $("input[name='domain']", this).val()
      bid       = "#{subdomain}.#{domain}"
      console.log $("input[name='bid']", this)
      $("input[name='bid']", this).val bid
      $("input[name='url']", this).val "http://#{bid}/"
    .validate
      submitHandler: @new_blog
      rules:
        subdomain:
          required: true
        url:
          url: true
        bid:
          remote: "/check/bid"

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