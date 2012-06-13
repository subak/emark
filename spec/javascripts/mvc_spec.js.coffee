jasmine.getFixtures().fixturesPath = "public/emark.jp"
html = jasmine.getFixtures().read("dashboard.html")

describe "token", ->
  beforeEach ->
    jasmine.getFixtures().set(html)
    @server = sinon.fakeServer.create()
    @token  = Emark.app.pages.token
    @ajax   = sinon.spy(jQuery, "ajax")

  afterEach ->
    @server.restore()
    jQuery.ajax.restore()

  it "should return", ->
    @server.respondWith "GET", "/", [
      200,
      "Content-Type": "text/plain"
      ,"http://www.example.com/"
    ]

    @token.active()
    @server.respond()

    @ajax.getCall(0).returnValue.done (redirect) ->
      expect(redirect).toEqual "http://www.example.com/"

  it "失敗ステータスコード", ->
    @server.respondWith "GET", "/", [
      500,
      "Content-Type": "text/plain"
      ,"http://www.example.com/"
    ]

    @token.active()
    @server.respond()

    expect($("#error")).not.toBeHidden


describe "dashbaord", ->
  beforeEach ->
    jasmine.getFixtures().set(html)
    @server    = sinon.fakeServer.create()
    @dashboard = Emark.app.pages.dashboard

  afterEach ->
    @server.restore()

  it "should", ->
    @server.respondWith "GET", "/blogs", [
      200,
      "Content-Type": "application/json"
      ,'[{"id":1, "title":"title", "bid":"test.example.com"}]'
    ]

    @dashboard.active()
    @server.respond()

    expect($(".blog-table").size()).toEqual 1
    expect($(".blog-table h3 a")).toHaveAttr "href", "http://test.example.com/"

    @dashboard.switch_to_edit_mode()
    expect(@dashboard.edit_success).toBeHidden()
    expect(@dashboard.edit_danger).not.toBeHidden()

