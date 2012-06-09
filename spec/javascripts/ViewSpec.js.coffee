# encoding:utf8

jasmine.getFixtures()

describe "hoge", ->
  TestController = null
  beforeEach ->
    class TestController extends Spine.Controller
      getView: (name) ->
        @view name
        
  it "huga", ->
    app = new App({el: document.documentElement})
    test = new TestController
    expect(test.view("pages/show")()).toMatch /<p>/
    expect("hoge").toBe "hoge"

  it "test", ->
    loadFixtures "test.html"
    expect(document).toContain("p")
    app = new App el: $("div#show")