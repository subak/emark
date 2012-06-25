class Controller.Token extends Spine.Controller
  active: ->
    $.ajax
      url:      "/"
      data:     location.search.substr 1
      dataType: 'text'
    .fail =>
      @trigger "forbidden"
    .done ( redirect ) =>
      location.href = redirect   


class Controller.Dashboard extends Spine.Controller
  config: Emark.config
  events:
    "click #open-blog > a":     "navigate_to_open"
    "click a[class~='config']": "navigate_to_config"
    "click a[class~='sync']":   "sync"
    "click a[class~='delete']": "delete_blog"
    "click .btn-danger":        "switch_to_edit_mode"
    "click .btn-success":       "switch_to_normal_mode"

  elements:
    "#edit-blogs":              "edit_blogs"
    ".edit-danger":             "edit_danger"
    ".edit-success":            "edit_success"
    "#edit-blogs .btn-danger":  "btn_danger"
    "#edit-blogs .btn-success": "btn_success"

  active: ->
    if 1 <= Model.Blog.count()
      @delay((=> @render()), 500)
    else
      Model.Blog.fetch()
      Model.Blog.one "refresh", @render

  render: =>
    @blogs = Model.Blog.all()
    @replace @view("blogs")(@)
    @refreshElements()
    @attach_edit()
    @trigger "loaded"

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

  delete_blog: (event)=>
    event.preventDefault()
    if confirm($(event.currentTarget).data('msg'))
      @stack.loading.trigger "show"
      @navigate $(event.currentTarget).attr("href")

  attach_edit: =>
    @edit_danger.hide()
    if 0 != @blogs.length
      @edit_blogs.removeClass("hidden")
      @btn_success.hide()

  switch_to_edit_mode: =>
    @edit_success.hide()
    @edit_danger.show()
    @btn_success.show()
    @btn_danger.hide()

  switch_to_normal_mode: =>
    @edit_success.show()
    @edit_danger.hide()
    @btn_success.hide()
    @btn_danger.show()


class Controller.Config extends Spine.Controller
  config: Emark.config
  active: (params)->
    @bid = params.bid
    if Model.Blog.findByAttribute("bid", @bid)
      @delay((=> @render()), 500)
    else
      Model.Blog.fetch()
      Model.Blog.one "refresh", @render

  render: =>
    @blog = Model.Blog.findByAttribute("bid", @bid)
    @trigger "fatal" if not @blog
    @trigger "loaded"
    @replace @view("config")(@)
    @el.modal "show"

  events:
    "click .nav-tabs a": "switch_tab"
    "submit form":       "submit"
    "hide":              "hide"
    "hidden":            "hidden"
  hide:   => @trigger "loading"
  hidden: => @navigate "/dashboard"

  switch_tab: (event)->
    event.preventDefault()
    $(event.currentTarget).tab("show")

  submit: (event)->
    event.preventDefault()
    blog = @blog.fromForm(event.currentTarget)
    blog.save()
    blog.one "ajaxSuccess", => @el.modal "hide"
    @trigger "loading"


class Controller.Sync extends Spine.Controller
  active: (params)->
    @bid = params.bid
    Model.Sync.one "refresh", @render
    Model.Sync.fetch(id: @bid)

  render: =>
    @model = Model.Sync.find(@bid)
    @trigger "fatal" if not @model
    @replace @view("sync")(@)
    @el.modal "show"
    @trigger "loaded"

  events:
    "hide":   "hide"
    "hidden": "hidden"
  hide:   => @trigger "loading"
  hidden: => @navigate "/dashboard"


class Controller.Open extends Spine.Controller
  config: Emark.config
  active: ->
    Model.Notebook.one "refresh", @render
    Model.Notebook.fetch()

  render: =>
    @trigger "loaded"
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
    blog.save()
    @stack.loading.trigger "show"

  updated: (blog)=>
    @el.modal "hide"

  shown: ->
    @$("form").submit (event)->
      subdomain = $("input[name='subdomain']", this).val()
      domain    = $("input[name='domain']", this).val()
      bid       = "#{subdomain}.#{domain}"
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


class Controller.Close extends Spine.Controller
  active: (params)->
    blog = Model.Blog.findByAttribute("bid", params.bid)
    return @stack.error.trigger("show") if not blog
    blog.destroy()
    blog.one "ajaxSuccess", @destroyed
  destroyed: => @navigate "/dashboard"


class Controller.Logout extends Spine.Controller
  config: Emark.config
  active: ->
    session = new Model.Session id: $.cookie("sid")
    session.destroy()
    session.one "ajaxSuccess", @logouted
  logouted: =>
    location.href = @config.site_href
    

class Controller.Loading extends Spine.Controller
  constructor: ->
    @el = @view("loading")()
    @bind "hide", -> @el.fadeOut()
    @bind "show", -> @el.show()
    super


class Controller.Error extends Spine.Controller
  constructor: ->
    @el = @view("error")()
    @bind "show", -> @el.show()
    super