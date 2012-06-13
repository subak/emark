new App

# class Model.Sync extends Spine.Model
#   @configure "Sync", "queued", "bid"
#   @extend Spine.Model.Ajax
#   @url: "/sync"
#   url: ->
#     "/hogehuga"

describe "Model.Sync", ->
  # beforeEach ->
  #   @server = sinon.fakeServer.create()
  # afterEach ->
  #   @server.restore()

  it "should request", ->
    spy = sinon.spy(jQuery, 'ajax');
#    sync = Model.Sync.create()
#    sync = new Model.Sync(id: "test.example.com")
#    sync = Model.Sync.fetch()
    sync = Model.Sync.find(1, {queued: false})
#    sync = Model.Sync.fetch({id: 3})
#    console.log sync.url()


    #Model.Sync.update("test.example.com", {})


    console.log spy.getCall(0)


xdescribe "Model.Blog", ->
  blog = null
  beforeEach ->
    @server = sinon.fakeServer.create()

  afterEach ->
    @server.restore()

  it "should fire the refresh event", ->
    callback = sinon.spy()

    @server.respondWith "GET", "/blogs", [
      200,
      "Content-Type": "application/json"
      ,'[{"id":1, "bid":"test.example.com", "title":"hoge"}]'
    ]

    Model.Blog.one "refresh", callback
    Model.Blog.fetch()

    @server.respond()

    expect(callback.called).toBeTruthy()

    blogs = Model.Blog.all()

    expect(blogs.length).toEqual 1
    blog = blogs[0]

    expect(blog.id).toEqual 1
    expect(blog.title).toEqual "hoge"

    spy = sinon.spy(jQuery, 'ajax')
    blog.sync()
    console.log spy.getCall(0) 

# 　  blogs = callback.getCall(0).args[0]
#     console.log blogs
    

    # expect(callback.getCall(0).args[0].attributes).toEqual
    #   id: 1
    #   title: "hoge"


    # blog = new Model.Blog
    #   bid:      "test.example.com"
    #   notebook: "89343-39843-234"
    #   title:    "title"
    #   subtitle: "subtitle"
    #   author:   "author"
