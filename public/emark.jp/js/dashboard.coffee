jQuery.ajaxSetup cache: false

##
# Model
class Domino.Model.Blogs extends Domino.Model
  load: ->
    df = jQuery.Deferred()
    df.fail =>
      @trigger 'load_fail'
    df.done =>
      @trigger 'load_done'

    jQuery.ajax("/dashboard")
    .fail =>
      df.reject()
    .pipe ( json )=>
      @set json
      df.resolve(@)

    df.promise()

  remove: ( blogid )->
    df = jQuery.Deferred()
    df.fail =>
      @trigger 'remove_fail'
    df.done =>
      @trigger 'remove_done'

    jQuery.ajax
      url:  "/close/#{blogid}"
      type: "DELETE"
    .fail =>
      df.reject()
    .pipe ( json )=>
      df.resolve(json)

    df.promise()

class Domino.Model.Publish extends Domino.Model
  load: ->
    df = jQuery.Deferred()
    df.fail =>
      @trigger 'load_fail'
    df.done =>
      @trigger 'load_done'

    jQuery.ajax("/open")
    .fail =>
      df.reject()
    .pipe ( json )=>
      @set json
      df.resolve(@)

    df.promise()

  save: ( data )->
    df = jQuery.Deferred()
    df.fail =>
      @trigger 'save_error'
    df.done =>
      @trigger 'save_after'

    jQuery.ajax
      url:  "/open"
      type: "POST"
      data: data
    .fail =>
      df.reject()
    .done =>
      df.resolve()

    @trigger 'save_before'
    df.promise()

  check: ( blogid )->
    df = jQuery.Deferred()
    df.fail =>
      @trigger 'check_error'
    df.done ( data )=>
      if data.available then @trigger 'check_ok' else @trigger 'check_ng'
      @trigger 'check_after', data

    jQuery.ajax
      url:  "/check/blogid/#{blogid}"
      type: "GET"
    .fail =>
      df.reject()
    .done ( data )=>
      df.resolve(data)

    @trigger 'check_before'
    df.promise()

class Domino.Model.Config extends Domino.Model
  load: ( blogid )->
    df = jQuery.Deferred()
    df.fail =>
      @trigger 'load_fail'
    df.done =>
      @trigger 'load_done'

    jQuery.ajax("/config/#{blogid}")
    .fail =>
      df.reject()
    .pipe ( json )=>
      @set json
      df.resolve(@)

    df.promise()

  save: ( blogid, data )->
    df = jQuery.Deferred()
    df.fail =>
      @trigger 'error_save'
    df.done =>
      @trigger 'after_save'

    jQuery.ajax
      url:  "/config/#{blogid}"
      type: "PUT"
      data: data
    .fail =>
      df.reject()
    .done =>
      df.resolve()

    @trigger 'before_save'
    df.promise()


##
# View

# ルート
class Domino.View.Root extends Domino.View
  subject: 'body'
  show:    ->
  hide:    ->
  events:  ->
    @el.on 'click', "a[href='/logout']", ( event ) =>
      event.preventDefault()
      @trigger 'logout'

# エラー画面
class Domino.View.Error extends Domino.View
  subject: "#error"

# ローディング画面
class Domino.View.Loading extends Domino.View
  subject: "#loading"
  show:    -> @el.fadeIn()
  hide:    -> @el.fadeOut()

# ブログ一覧ウィジェット
class Domino.View.IndexContainer extends Domino.View.Template
  subject: "#index-container"
  show:    -> @el.fadeIn()
  events:  ->

    @el.on 'click', "a[href^='/close']", ( event )=>
      event.preventDefault()
      if !confirm $(event.currentTarget).attr("data-msg")
        event.stopImmediatePropagation()

    # action
    @el.on 'click', "a[data-state]", ( event ) =>
      event.preventDefault()
      @trigger 'action', $(event.currentTarget)

    open        = "#open-blog"
    edit        = "#edit-blogs"
    editSuccess = ".btn-success" 
    editDanger  = ".btn-danger"
    success     = ".edit-success"
    danger      = ".edit-danger"

    # 初期化
    @bind 'render_after', =>
      if 0 != @el.find(".blogs").size()
        @el.find(edit).removeClass 'hidden'
        @el.find(edit).find(editSuccess).hide()
        @el.find(danger).hide()

    @el.on 'click', edit, ( event )=>
      button = $(event.currentTarget)

      # 編集
      if !button.find(editDanger).is(":hidden")
        @el.find(open).slideUp()
        button.find(editDanger).slideUp =>
          @el.find(success).slideUp()
          @el.find(danger).slideDown()
          button.find(editSuccess).slideDown()
      else
        button.find(editSuccess).slideUp =>
          @el.find(open).slideDown()
          @el.find(success).slideDown()
          @el.find(danger).slideUp()
          button.find(editDanger).slideDown()

# 同期
class Domino.View.Sync extends Domino.View.Template
  subject: "#sync"
  show:    -> @el.modal 'show'
  hide:    -> @el.modal 'hide'
  events:  ->
    @el.on "hidden", => @trigger "hidden"

# 設定モーダルウィンドウ
class Domino.View.ConfigModal extends Domino.View.Template
  subject: "#config-modal"
  show:    -> @el.modal 'show'
  hide:    -> @el.modal 'hide'
  events:  ->
    @bind "render_after", =>

      # selectのoptionを自動生成して選択
      @el.find("select[data-range]").each ->
        $select = $(@)
        for i in [parseInt($select.attr("data-min"), 10)..parseInt($select.attr("data-max"), 10)]
          $select.append "<option value='#{i}'>#{i}</option>"
        $select.val $select.attr("data-value")

    # タブ
    @el.on "click", "a", ( event )=>
      event.preventDefault()
      $(event.currentTarget).tab('show')

    # このビューに対してhiddenイベントを定義
    @el.on 'hidden', ( event ) =>
      @trigger 'hidden', event

    @el.on 'submit', 'form', ( event ) =>
      event.preventDefault()
      @trigger 'submit', @el.find('form').serialize()


# ブログ公開ページ
class Domino.View.PublishContainer extends Domino.View.Template
  subject: "#publish-container"
  show:    -> @el.modal 'show'
  hide:    -> @el.modal 'hide'
  events:  ->
    # 非表示になった時にpushStateを発動
    @el.on 'hidden', ( event ) => @trigger 'hidden', event

    @guid      = "[name='notebookGuid']"
    @domain    = "[name='domain']"
    @subdomain = "[name='subdomain']"
    @submit    = "button[type='submit']"
    @cancel    = "button[data-dismiss='modal']"
    @group     = ".control-group"
    @msgDomainInvalid = "#msg-domain-invalid" 
    @msgDomainDouble  = "#msg-domain-double"
    @msgDomainEmpty   = "#msg-domain-empty"
    @msgConfirm       = "#msg-confirm" 

    # validator
    tid = null
    @el.on "keyup", "form :text[name='subdomain']", ( event ) =>
      clearTimeout tid if tid?
      tid = setTimeout =>
        domain    = @el.find(@domain).val()
        subdomain = event.currentTarget.value

        if subdomain.length != 0
          @el.find(@msgDomainEmpty).addClass('hidden').
            parents(@group).first().removeClass('error')

        if subdomain.match(/^(([0-9a-z]+[.-])+)?[0-9a-z]+$/) or subdomain.length == 0
          @el.find(@msgDomainInvalid).addClass('hidden').
            parents(@group).first().removeClass('error')

          # サーバに問い合わせ
          @trigger 'check_blogid', "#{subdomain}.#{domain}"
        else
          @el.find(@msgDomainInvalid).removeClass('hidden').
            parents(@group).first().addClass('error')
      , 500

    # domainのチェックに通った
    @bind 'blogid_ok', =>
      @el.find(@msgDomainDouble).addClass('hidden').
        parents(@group).first().removeClass('error')

    # domainのチェック失敗
    @bind 'blogid_ng', =>
      @el.find(@msgDomainDouble).removeClass('hidden').
        parents(@group).first().addClass('error')

    # 送信ボタン押した時
    @el.on 'submit', 'form', ( event )=>
      event.preventDefault()

      if @el.find(@subdomain).val().length == 0
        @el.find(@msgDomainEmpty).removeClass('hidden').
          parents(@group).first().addClass('error')

      if !@el.find(@group).is(".error")
        msg = @el.find(@submit).attr 'data-msg-confirm'
        @trigger 'submit', @el.find('form').serialize() if confirm msg

##
# Controller
# MVCの関係性を定義
app = new Domino.Controller

# model
app.set_model 'blogs',   Domino.Model.Blogs, ->
  change:      ( data )=> @view('index').build(data)
  load_fail:   =>         @trigger 'reject'
  remove_fail: =>         @trigger 'reject'

app.set_model 'config',  Domino.Model.Config, ->
  change:      ( data )=> @view('config').build data
  load_fail:   =>         @trigger 'reject'
  before_save: =>         @view('loading').show()
  after_save:  =>         @view('config').hide()
  error_save:  =>         @trigger 'reject'

app.set_model 'publish', Domino.Model.Publish, ->
  change:      ( data )=> @view('publish').build data
  load_fail:   =>         @trigger 'reject'
  check_error: =>         @trigger 'reject'
  check_ok:    =>         @view('publish').trigger 'blogid_ok'
  check_ng:    =>         @view('publish').trigger 'blogid_ng'
  save_error:  =>         @trigger 'reject'
  save_before: =>         @view('loading').show()
  save_after:  =>         @view('publish').hide()

# view
app.set_view 'loading', Domino.View.Loading
app.set_view 'error',   Domino.View.Error
app.set_view 'root',    Domino.View.Root, ->
  logout: => @reroute "/logout", false

app.set_view 'index',   Domino.View.IndexContainer, ->
  action: ( anchor )=>
    if anchor.is("[data-state='push']")
      @reroute anchor.attr("href")
    else if anchor.is("[data-state='replace']")
      @reroute anchor.attr("href"), false

app.set_view 'publish', Domino.View.PublishContainer, ->
  hidden:       =>           @reroute '/dashboard', false
  check_blogid: ( blogid )=> @model('publish').check blogid
  submit:       ( data )=>   @model('publish').save data

app.set_view 'config',  Domino.View.ConfigModal, ->
  hidden: =>
    @reroute '/dashboard', false
  submit: ( data )=>
    blogid = location.pathname.replace /^\/config\//, ''
    @model('config').save blogid, data

app.set_view 'sync', Domino.View.Sync, ->
  hidden: => @reroute '/dashboard', false


# controller
app.binding ->
  before_run: =>
    view.reset() for name, view of @views when name != 'loading'
    @view('loading').show()
  resolve: =>
    @view('loading').hide()
  reject: =>
    @view('error').show()

##
# routing
app.route "/", ->
  $.ajax
    url:      "/"
    data:     location.search.substr 1
    dataType: 'text'
  .fail =>
    @trigger 'reject'
  .done ( redirect ) =>
    location.href = redirect

app.route "/dashboard", ->
  @model('blogs').load()
  .done =>
    @view('index').render()    
    @trigger 'resolve'

app.route "/open", ->
  @model('publish').load()
  .done =>
    @view('publish').render()
    @trigger 'resolve'

app.route "/config/:blogid", ( blogid )->
  @model('config').load(blogid)
  .done =>
    @view('config').render()
    @trigger 'resolve'

app.route "/sync/:blogid", ( blogid )->
  $.ajax
    url:  "/sync/#{blogid}"
    type: "PUT"
  .fail =>
    @trigger 'reject'
  .done ( data )=>
    @view('sync').build data
    @view('sync').render()
    @trigger 'resolve'

app.route "/close/:blogid", ( blogid )->
  @model('blogs').remove(blogid)
  .done =>
    @reroute '/dashboard', false

app.route "/logout", ->
  $.ajax
    url:      "/logout"
    type:     "DELETE"
    dataType: "text"
  .fail =>
    @trigger 'reject'
  .done ( redirect ) =>
    location.href = redirect

##
# run
init = history.pushState?
$(window).on 'popstate', ->
  if init
    init = false
  else
    console.log new Date
    app.run location.pathname

$.ajax('/config.json')
.done ( json )->
  app.binding ->
    @view('publish').bind 'render_before', =>
      @view('publish').build json, 'config'

    binding_after: ->
      tpl = new Subak.Template document.documentElement
      tpl.load json
      tpl.close()

  app.bind "binding_after", ->
    tpl = new Subak.Template document.documentElement
    tpl.load json
    tpl.close()
  app.run location.pathname
