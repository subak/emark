$ = jQuery

##
# Model

class Domino.Model.Meta extends Domino.Model
  load: ->
    df = jQuery.Deferred()
    df.fail =>
      @trigger 'load_fail'
    df.done =>
      @trigger 'load_done'

    jQuery.ajax("/meta.json")
    .fail =>
      df.reject()
    .pipe (json) =>
      @set json
      df.resolve(@)

    df.promise()

class Domino.Model.Index extends Domino.Model
  entries: null
  ##
  # env
  #   archives:    Bool
  #   numOfRecent: Number
  #   numOfEntry:  Number
  #   page:        Number
  #   eid:         String
  load: ( env={} )->
    df = jQuery.Deferred()
    df.fail =>
      @trigger 'load_fail'
    df.done =>
      @trigger 'load_done'

    $.ajax('/index.json')
    .fail =>
      df.reject()
    .done ( json ) =>
      @entries = []
      for eid, entry of json
        @entries.push entry
      @entries.sort ( a, b )->
        Date.parseISO8601(b.created) - Date.parseISO8601(a.created)

      @set json

      @trigger 'recent',   @recent_posts(env.numOfRecent) if env.numOfRecent?
      @trigger 'archives', @archives() if env.archives?
      @trigger 'nav',      @entry_nav(env.eid) if env.eid?

      if env.page? and env.numOfEntry?
        @trigger 'pager', @pager(env.page, env.numOfEntry)

        promises = []
        for eid in @eids(env.page, env.numOfEntry)
          promises.push (new Domino.Model.Entry).load(eid)

        entries = []
        jQuery.when.apply(window, promises)
        .fail ->
          df.reject()
        .done =>
          for modelEntry in arguments
            modelEntry.transform()
            entries.push modelEntry.select()
          @trigger 'entries', entries:entries
          df.resolve(@)       
      else
        df.resolve(@)

    df.promise()

  eids: ( page, num ) ->
    page ?= 1
    from = (page - 1) * num
    to   = page * num

    eids = []
    i = -1
    for entry in @entries
      i++
      continue if i < from
      break if i >= to
      eids.push entry.eid
    eids

  pager: ( page, num ) ->
    count = 0
    count++ for eid, entry of @json

    page ?= 1
    from = (page - 1) * num
    to   = page * num

    data = {}
    data.newer = page - 1 if page > 1
    data.older = parseInt(page, 10) + 1 if count > to

    data

  recent_posts: ( num ) ->
    recent_posts = []
    i = 0
    for entry in @entries
      break if i >= num
      recent_posts.push
        eid:   entry.eid
        title: entry.title
      i++

    return {recent_posts:recent_posts}

  entry_nav: ( eid ) ->
    previous = @json[eid].previous
    next     = @json[eid].next

    data = {}
    data.previous          = previous if previous
    data.next              = next if next
    data.previousPostTitle = @json[previous].title if previous
    data.nextPostTitle     = @json[next].title if next

    return data

  archives: ->
    archives = []
    M = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']    


    # for eid, entry of @json
    #   archive = {}
    for entry in @entries
      archive = {}
      archive.eid   = entry.eid
      archive.title = entry.title
      for label in ['created', 'updated']
        date = Date.parseISO8601(entry[label])
        n    = date.getMonth()
        d    = date.getDate()
        archive["#{label}_n"] = n
        archive["#{label}_d"] = if d <= 9 then "0#{d}" else d
        archive["#{label}_j"] = d
        archive["#{label}_Y"] = date.getFullYear()
        archive["#{label}_M"] = M[n]
      archives.push archive

    return {archives:archives}

class Domino.Model.Entry extends Domino.Model
  load: ( eid ) ->
    df = jQuery.Deferred()

    $.ajax("/#{eid}.json")
    .fail ->
      df.reject()
    .done ( data ) =>
      @set data
      df.resolve(@)

    df.promise()

  set: (json) ->
    super(json)
    @trigger 'entries', entries:@select()

  transform: ->
    M = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    for label in ['created', 'updated']
      date = Date.parseISO8601(@json[label])
      n    = date.getMonth()
      d    = date.getDate()
      @json["#{label}_n"] = n
      @json["#{label}_d"] = if d <= 9 then "0#{d}" else d
      @json["#{label}_j"] = d
      @json["#{label}_Y"] = date.getFullYear()
      @json["#{label}_M"] = M[n]

    re = new RegExp decodeURI("%C2%A0"), "g"
    @json.html = window.markdown.toHTML(@json.markdown.replace re, " ")

##
# View
class Domino.View.Recent extends Domino.View.Template
  subject: "#recent_posts"

class Domino.View.Archives extends Domino.View.Template
  subject: "div:has(>article>div#blog-archives)"

class Domino.View.Index extends Domino.View.Template
  subject: ".blog-index"

class Domino.View.Entry extends Domino.View.Template
  subject:    "#entry"

class Domino.View.Loading extends Domino.View
  subject: "#loading"

class Domino.View.Error extends Domino.View
  subject: "#error"

##
# Controller
app = new Domino.Controller

app.set_view 'index',    Domino.View.Index
app.set_view 'entry',    Domino.View.Entry, ->
  render_after:  =>
    # video 表示
    @view('entry').el.find("a").each ->
      href = $(@).attr('href')
      return true if !href.match(/\.([^./]+)$/)
      ext = RegExp.$1
      switch ext
        when "mp4", "ogg", "m4v"
          $(@).replaceWith "<video src='#{href}' controls></video>"

    # twitter
    if twttr?
      twttr.widgets.load()
    else
      jQuery.getScript "http://platform.twitter.com/widgets.js"

    # disqus
    if DISQUS?
      try
        DISQUS.reset
          reload: true
          config: ->
            @page.identifier = location.pathname.substr(1)
            @page.url        = location.href
      catch e
        console.log e

    else if @config.disqus? and 1 <= @config.disqus.length
      window.disqus_shortname  = @config.disqus
      window.disqus_identifier = location.pathname.substr(1)
      window.disqus_url        = location.href
      jQuery.getScript "http://#{@config.disqus}.disqus.com/embed.js", ->
        window.DISQUS = DISQUS

app.set_view 'archives', Domino.View.Archives
app.set_view 'recent',   Domino.View.Recent
app.set_view 'loading',  Domino.View.Loading
app.set_view 'error',    Domino.View.Error

app.set_model 'meta',  Domino.Model.Meta
app.set_model 'index', Domino.Model.Index, ->
  pager:    ( data )=> @view('index').build data
  recent:   ( data )=> @view('recent').build data
  entries:  ( data )=> @view('index').build data
  archives: ( data )=> @view('archives').build data
  nav:      ( data )=> @view('entry').build data

app.set_model 'entry', Domino.Model.Entry, ->
  refresh:  ( data )=> @view('entry').build data, 'entry'

app.binding ->
  jQuery(document.body).on 'click', 'a', ( event ) =>
    event.preventDefault()
    @reroute $(event.currentTarget).attr('href')

  before_run: =>
    view.reset() for name, view of @views
    @view('loading').show()
  resolve:    => @view('loading').hide()
  reject:     => @view('error').show()
  binding_after: =>

# app.binding ->
#   @numOfEntry  = 5
#   @numOfRecent = 5 


# index
app.route /^(?:\/|\/page\/(\d+))$/, ( page ) ->
  @model('index').load
    page:        page ? 1
    numOfEntry:  @config.num_of_index
    numOfRecent: @config.num_of_recent
  .done =>
    @view('index').render()
    @view('recent').render()
    @trigger 'resolve'

# archives
app.route '/archives', ->
  @model('index').load
    archives:    true
    numOfRecent: @config.num_of_recent
  .done =>
    @view('archives').render()
    @view('recent').render()
    @trigger 'resolve'

# entry
app.route /^\/([0-9a-zA-Z]{4})$/, ( eid ) ->
  $.when(@model('index').load(eid:eid,numOfRecent:@config.num_of_recent), @model('entry').load(eid))
  .done =>
    @view('entry').build location, 'location'
    @view('entry').render()
    @view('recent').render()
    @trigger 'resolve'

init = history.pushState?
$(window).on 'popstate', ->
  if init
    init = false
  else
    console.log new Date
    app.run location.pathname

$.ajax('/meta.json')
.done ( data )->
  if data.twitter? and 1 <= data.twitter.length
    $ = window.octopress
    getTwitterFeed(data.twitter, 4, false)
    $ = jQuery
  app.config = data
  data.now_Y = (new Date()).getFullYear()
  (new Subak.Template document.documentElement).load $.extend(data, location), 'meta'
  app.run location.pathname

