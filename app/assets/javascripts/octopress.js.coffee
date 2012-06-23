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
  active: (params)->
    @deferred = $.Deferred()
    @params   = params
    @entry    = Entry.find(@id)
    @blog     = Blog.first()
    @entry.bind "update", @render
    if @entry.markdown?
      @entry.trigger "update"
    else
      $.ajax("/#{@id}.json")
      .done (obj)=>
        @entry.updateAttribute "markdown", obj.markdown
    @deferred.promise()
  render: =>
    @replace @include("article")(@)
    @deferred.resolve()


class Index extends Spine.Controller
  active: (params={})->
    @el.empty()
    @deferred = $.Deferred()
    @params        = params
    @entries       = []
    Entry.one "refresh", @render
    @deferred.promise()
  render: =>
    @blog = Blog.first()
    page  = @params.page || 1
    page  = parseInt(page, 10)
    limit = 10
    from  = (page - 1) * limit
    to    = from + limit
    count = Entry.count()

    @next_page     = if count >= to + limit then page + 1 else null
    @previous_page = unless page == 1 then page - 1 else null

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
      promises.push new Article(id: entry.id, el: $("#eid-#{entry.id}")).active(@params)
    $.when.apply(this, promises).done => @deferred.resolve()


class Post extends Spine.Controller
  active: (params={})->
    @el.empty()
    @deferred = $.Deferred()
    @params   = params
    Entry.one "refresh", @render
    @deferred.promise()
  render: =>
    entry     = Entry.find(@params.eid)
    @previous = if Entry.exists(entry.previous) then Entry.find(entry.previous)  else null
    @next     = if Entry.exists(entry.next) then Entry.find(entry.next) else null
    @entry    = entry
    @blog     = Blog.first()
    @el       = $("#content > div")
    @replace @view("post")(@)
    promise = new Article(id: entry.id, el: $("#eid-#{entry.id}")).active(@params)
    
    $.when(promise).done =>
      @deferred.resolve()


class Archives extends Spine.Controller
  active: ->
    @el.empty()
    @deferred = $.Deferred()
    Entry.one "refresh", @render
    @deferred.promise()
  render: =>
    @meta_entries = Entry.all()
    @el = $("#content > div")
    @replace @view("archives")(@)
    @deferred.resolve()


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


class Footer extends Spine.Controller
  active: ->
    Entry.one "refresh", @render
    @deferred = $.Deferred()
    @deferred.promise()
  render: =>
    @blog = Blog.first()
    @html @include("footer")(@)
    @deferred.resolve()


class App extends Spine.Controller
  constructor: ->
    @pages = {
      index:    new Index,
      post:     new Post,
      archives: new Archives
    }

    asides = [
      new AboutMe(el: $("#content > aside.sidebar > section:nth-child(1)")),
      new RecentPosts(el: $("#content > aside.sidebar > section:nth-child(2)")),
      new Footer(el: $('body > footer[role="contentinfo"]'))
    ]
    @promises = (aside.active() for aside in asides)

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
      "/":           (params)-> @activate("index",    params)
      "/page/:page": (params)-> @activate("index",    params)
      "/archives":   (params)-> @activate("archives", params)
      "/:eid":       (params)-> @activate("post",     params)
    Spine.Route.setup history: true

  activate: (name, params)->
    promise = @pages[name].active(params)
    if Entry.count() != 0
      Entry.trigger "refresh"
      $("body").scrollTop $("body > nav").offset().top
      $.when(promise).done => @activated(name, params)
    else
      @promises.push promise
      $.when.apply(this, @promises).done => @ready(name); @activated(name, params)

  activated: (name, params)->
    blog = Blog.first()
    switch name
      when "index", "archives"
        title = blog.title
        href  = "/"
      when "post"
        entry = Entry.find(params.eid)
        title = "#{entry.title} - #{blog.title}"
        href  = "/#{params.eid}"

    $("title").text title
    $('link[href="/atom.xml"]').attr "title", blog.title.toString()
    $('meta[name="author"]').attr "content", blog.author
    $('link[rel="canonical"]').attr "href", href

    $('a:not([target="_blank"]):not([href^="/"])').each ->
      href = $(this).attr("href")
      $(this).attr("target", "_blank") if -1 == href.indexOf(blog.bid)

  ready: (name)->
    $.getScript "http://www.cdn-cache.com/20120506/octopress/javascripts/octopress.js"

  binding: ->
    $("body").on "click", "a", (event)=>
      href = $(event.currentTarget).attr("href")
      if href.match(/^(\/|\/page\/\d+|\/archives|\/[0-9a-zA-Z]{4})$/)
        event.preventDefault()
        @navigate href

  init: =>
    blog = Blog.first()
    $header = $('body > header[role="banner"]')
    $header.find("h1 a").html(blog.title)
    $subtitle = $header.find("h2")
    if blog.subtitle?.length != 0
      $subtitle.html blog.subtitle
    else
      $subtitle.remove()
    $('fieldset[role="search"] > input:hidden').val "site:#{blog.bid}"

new App
jQuery.noConflict();