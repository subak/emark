# encoding:utf8

describe "hoge", ->
  TestController = null
  beforeEach ->
    class TestController extends Spine.Controller
      getView: (name) ->
        @view name
        
  it "huga", ->
    test = new TestController
    expect(test.view("pages/show")()).toMatch /<p>/
    expect("hoge").toBe "hoge"