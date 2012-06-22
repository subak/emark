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

class Index extends Spine.Controller
  active: (params={})->
    @params = params
    @el.empty()
    Entry.one "refresh", @render

  render: =>
    @blog = Blog.first()
    @entries = []

    i = 0
    for entry in Entry.all()
      @entries.push entry
      break if ++i >= 10

    @el = $("#content > div")
    @replace @view("index")(@)

    context =
      blog:   @blog
      params: @params
      date:   @date

    for entry in @entries
      include = @include("article")
      do (entry)->
        entry.unbind "update"
        entry.bind "update", =>
          $("#" + entry.id).replaceWith include($.extend context, entry: entry)
        if entry.markdown?
          entry.trigger "update", entry
        else
          $.ajax("/#{entry.id}.json")
            .done (obj)->
              entry.updateAttribute "markdown", obj.markdown


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

    entry.unbind "update"
    entry.bind "update", (model)=>
      $('#' + model.id).replaceWith @include("article")(blog: @blog, entry: model, params:@params, date:@date)
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
  constructor: ->
    @el = $("#content > aside.sidebar")
    Entry.one "refresh", @render
  render: =>
    @posts = Entry.all()
    @html @include("asides/recent_posts")(@)

class App extends Spine.Controller
  constructor: ->
    @pages = {
      index:    new Index,
      post:     new Post,
      archives: new Archives
    }

    new RecentPosts root: @

    Blog.one "refresh", @init
    $.when($.ajax("/meta.json"), $.ajax("/index.json"))
    .done (ajax1, ajax2)->
      blog = ajax1[0]
      entries = ajax2[0]
      Blog.refresh blog

      pre_entry = null
      for entry in entries
        entry.previous  = pre_entry?.id
        pre_entry?.next = entry.id
        pre_entry = entry

      Entry.refresh entries

    @routes
      "/":           ->
        @pages.index.active()
        Entry.trigger "refresh" if Entry.count() != 0
      "/page/:page": (params)-> @pages.index.active(params)
      "/archives":   ->
        @pages.archives.active()
        Entry.trigger "refresh" if Entry.count() != 0
      "/:eid":       (params)->
        @pages.post.active(params)
        Entry.trigger "refresh" if Entry.exists(params.eid)

    Spine.Route.setup history: true

    $("body").on "click", "a", (event)=>
      href = $(event.currentTarget).attr("href")
      console.log href
      if href.match(/^(\/|\/page\/\d+|\/archives|\/[0-9a-zA-Z]{4})$/)
        event.preventDefault()
        @navigate href
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


new App
jQuery.noConflict();