#= require jquery
#= require jquery_ujs
#= require_tree ./lib
#= require hamlcoffee
#= require spine
#= require spine/manager
#= require spine/ajax
#= require spine/route
#= require_tree ./octopress
#= require_self

$ = jQuery

Spine.Controller.include
  view: (name) ->
    JST["octopress/views/layouts/#{name}"] || -> "not found"
  include: (name) ->
    JST["octopress/views/includes/#{name}"] || -> "not found"
  date: (time) ->
    date = new Date(time)
    date.getMonthName = ->
      M = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
      M[this.getMonth()]
    date

class Blog extends Spine.Model
  @configure "Blog", "title", "subtitle", "author"

class Entry extends Spine.Model
  @configure "Entry", "title", "created", "updated", "previous", "next", "markdown"

class Article extends Spine.Controller
  constructor: ->
    super
    entry = Entry.find(@id)
    entry.bind "update", @render

    $.ajax("/#{@id}.json")
    .done (obj)->
      entry.updateAttribute "markdown", obj.markdown

    @entry = entry
    @blog  = Blog.first()
    @deferred = $.Deferred()
  render: =>
    @replace @include("article")(@)
    @deferred.resolve()    
  rendered: ->
    @deferred.promise()

class Index extends Spine.Controller
  active: (params={})->
    @el.empty()
    @params        = params
    @next_page     = null
    @previous_page = null
    @entries       = []
    @deferred      = $.Deferred()
    Entry.one "refresh", @render
  renderd: -> @deferred.promise()
  render: =>
    @blog = Blog.first()

    page  = @params.page || 1
    page  = parseInt(page, 10)
    limit = 10
    from  = (page - 1) * limit
    to    = from + limit
    count = Entry.count()

    @next_page     = page + 1 if count >= to + limit
    @previous_page = page - 1 unless page == 1

    i = 0
    for entry in Entry.all()
      break if i >= to
      if i >= from
        @entries.push entry
      i += 1

    @el = $("#content > div")
    @replace @view("index")(@)

    promises = []
    for entry in @entries
      promises.push new Article(id: entry.id, el: $("#eid-#{entry.id}"))
    $.when(promises).done => @deferred.resolve()

class Post extends Spine.Controller
  active: (params={})->
    @params = params
    @el.empty()
    Entry.one "refresh", @render
    @previous = null
    @entry    = null

  render: =>
    @blog = Blog.first()

    entry = Entry.find(@params.eid)
    @previous = Entry.find(entry.previous) if Entry.exists(entry.previous)
    @next     = Entry.find(entry.next) if Entry.exists(entry.next)
    @entry    = entry

    @el = $("#content > div")
    @replace @view("post")(@)

    context =
      blog:   @blog
      params: @params
      date:   @date

    entry.unbind "update"
    entry.bind "update", (model)=>
      $('#' + model.id).replaceWith @include("article")($.extend context, entry: model)
    if entry.markdown?
      entry.trigger "update", entry
    else
      $.ajax("/#{entry.id}.json")
      .done (obj)->
        entry.updateAttribute("markdown", obj.markdown)

class Archives extends Spine.Controller
  active: ->
    Entry.one "refresh", @render
  render: =>
    @meta_entries = Entry.all()
    @el = $("#content > div")
    @replace @view("archives")(@)

class RecentPosts extends Spine.Controller
  active: ->
    @deferred = $.Deferred()
    Entry.one "refresh", @render
    @deferred.promise()
  render: =>
    @posts = Entry.all()
    @replace @include("asides/recent_posts")(@)
    @deferred.resolve()

class AboutMe extends Spine.Controller
  active: ->
    @deferred = $.Deferred()
    Entry.one "refresh", @render
    @deferred.promise()
  render: =>
    @blog = Blog.first()
    if @blog.about?
      @replace @include("asides/about")(@)
    else
      @release()
    @deferred.resolve()

class App extends Spine.Controller
  constructor: ->

    asides = [
      new AboutMe(el: $("#content > aside.sidebar > section:nth-child(1)")),
      new RecentPosts(el: $("#content > aside.sidebar > section:nth-child(2)"))
    ]

    @pages = {
      index:    new Index,
      post:     new Post,
      archives: new Archives
    }

    @promises = (aside.active() for aside in asides)
    console.log @promises

    # promises.push @pages.index.renderd()
    # $.when(promises)
    # .done ->
    #   $.getScript "http://www.cdn-cache.com/20120506/octopress/javascripts/octopress.js"

    @binding()

    # init
    Blog.one "refresh", @init

    $.when($.ajax("/meta.json"), $.ajax("/index.json"))
    .done (ajax1, ajax2)->
      # blog
      blog = ajax1[0]
      entries = ajax2[0]
      Blog.refresh blog

      # entry
      pre_entry = null
      for entry in entries
        entry.previous  = pre_entry?.id
        pre_entry?.next = entry.id
        pre_entry = entry
      Entry.refresh entries

    @routes
      "/": (params)->
        @pages.index.active()
        @activate("index")
      "/page/:page": (params)->
        @pages.index.active(params)
        @activate("index")
      "/archives": (params)->
        @pages.archives.active()
        @activate("archives")
      "/:eid": (params)->
        @pages.post.active(params)
        @activate("post")
    Spine.Route.setup history: true

  binding: ->
    # binding
    $("body").on "click", "a", (event)=>
      href = $(event.currentTarget).attr("href")
      console.log href
      if href.match(/^(\/|\/page\/\d+|\/archives|\/[0-9a-zA-Z]{4})$/)
        event.preventDefault()
        @navigate href

  activate: (page)->
    if Entry.count() != 0
      Entry.trigger "refresh"
      $("body").scrollTop $("body > nav").offset().top
    else
      @promises.push @pages[page].renderd()

  init: =>
    blog = Blog.first()

    $header = $('body > header[role="banner"]')
    $header.find("h1 a").html(blog.title)
    $subtitle = $header.find("h2")
    if blog.subtitle.length != 0
      $subtitle.html blog.subtitle
    else
      $subtitle.remove()
    $('fieldset[role="search"] > input:hidden').val "site:#{blog.bid}"
    $('body > footer[role="contentinfo"]').html @include("footer")(blog: blog)

new App
jQuery.noConflict();