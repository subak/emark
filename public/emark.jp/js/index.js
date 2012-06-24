(function() {
  var $, app, init,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  $ = jQuery;

  Domino.Model.Meta = (function(_super) {

    __extends(Meta, _super);

    function Meta() {
      Meta.__super__.constructor.apply(this, arguments);
    }

    Meta.prototype.load = function() {
      var df,
        _this = this;
      df = jQuery.Deferred();
      df.fail(function() {
        return _this.trigger('load_fail');
      });
      df.done(function() {
        return _this.trigger('load_done');
      });
      jQuery.ajax("/meta.json").fail(function() {
        return df.reject();
      }).pipe(function(json) {
        _this.set(json);
        return df.resolve(_this);
      });
      return df.promise();
    };

    return Meta;

  })(Domino.Model);

  Domino.Model.Index = (function(_super) {

    __extends(Index, _super);

    function Index() {
      Index.__super__.constructor.apply(this, arguments);
    }

    Index.prototype.entries = null;

    Index.prototype.load = function(env) {
      var df,
        _this = this;
      if (env == null) env = {};
      df = jQuery.Deferred();
      df.fail(function() {
        return _this.trigger('load_fail');
      });
      df.done(function() {
        return _this.trigger('load_done');
      });
      $.ajax('/index.json').fail(function() {
        return df.reject();
      }).done(function(json) {
        var eid, entries, entry, promises, _i, _len, _ref;
        _this.entries = [];
        for (eid in json) {
          entry = json[eid];
          _this.entries.push(entry);
        }
        _this.entries.sort(function(a, b) {
          return Date.parseISO8601(b.created) - Date.parseISO8601(a.created);
        });
        _this.set(json);
        if (env.numOfRecent != null) {
          _this.trigger('recent', _this.recent_posts(env.numOfRecent));
        }
        if (env.archives != null) _this.trigger('archives', _this.archives());
        if (env.eid != null) _this.trigger('nav', _this.entry_nav(env.eid));
        if ((env.page != null) && (env.numOfEntry != null)) {
          _this.trigger('pager', _this.pager(env.page, env.numOfEntry));
          promises = [];
          _ref = _this.eids(env.page, env.numOfEntry);
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            eid = _ref[_i];
            promises.push((new Domino.Model.Entry).load(eid));
          }
          entries = [];
          return jQuery.when.apply(window, promises).fail(function() {
            return df.reject();
          }).done(function() {
            var modelEntry, _j, _len2;
            for (_j = 0, _len2 = arguments.length; _j < _len2; _j++) {
              modelEntry = arguments[_j];
              modelEntry.transform();
              entries.push(modelEntry.select());
            }
            _this.trigger('entries', {
              entries: entries
            });
            return df.resolve(_this);
          });
        } else {
          return df.resolve(_this);
        }
      });
      return df.promise();
    };

    Index.prototype.eids = function(page, num) {
      var eids, entry, from, i, to, _i, _len, _ref;
      if (page == null) page = 1;
      from = (page - 1) * num;
      to = page * num;
      eids = [];
      i = -1;
      _ref = this.entries;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        entry = _ref[_i];
        i++;
        if (i < from) continue;
        if (i >= to) break;
        eids.push(entry.eid);
      }
      return eids;
    };

    Index.prototype.pager = function(page, num) {
      var count, data, eid, entry, from, to, _ref;
      count = 0;
      _ref = this.json;
      for (eid in _ref) {
        entry = _ref[eid];
        count++;
      }
      if (page == null) page = 1;
      from = (page - 1) * num;
      to = page * num;
      data = {};
      if (page > 1) data.newer = page - 1;
      if (count > to) data.older = parseInt(page, 10) + 1;
      return data;
    };

    Index.prototype.recent_posts = function(num) {
      var entry, i, recent_posts, _i, _len, _ref;
      recent_posts = [];
      i = 0;
      _ref = this.entries;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        entry = _ref[_i];
        if (i >= num) break;
        recent_posts.push({
          eid: entry.eid,
          title: entry.title
        });
        i++;
      }
      return {
        recent_posts: recent_posts
      };
    };

    Index.prototype.entry_nav = function(eid) {
      var data, next, previous;
      previous = this.json[eid].previous;
      next = this.json[eid].next;
      data = {};
      if (previous) data.previous = previous;
      if (next) data.next = next;
      if (previous) data.previousPostTitle = this.json[previous].title;
      if (next) data.nextPostTitle = this.json[next].title;
      return data;
    };

    Index.prototype.archives = function() {
      var M, archive, archives, d, date, entry, label, n, _i, _j, _len, _len2, _ref, _ref2;
      archives = [];
      M = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      _ref = this.entries;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        entry = _ref[_i];
        archive = {};
        archive.eid = entry.eid;
        archive.title = entry.title;
        _ref2 = ['created', 'updated'];
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          label = _ref2[_j];
          date = Date.parseISO8601(entry[label]);
          n = date.getMonth();
          d = date.getDate();
          archive["" + label + "_n"] = n;
          archive["" + label + "_d"] = d <= 9 ? "0" + d : d;
          archive["" + label + "_j"] = d;
          archive["" + label + "_Y"] = date.getFullYear();
          archive["" + label + "_M"] = M[n];
        }
        archives.push(archive);
      }
      return {
        archives: archives
      };
    };

    return Index;

  })(Domino.Model);

  Domino.Model.Entry = (function(_super) {

    __extends(Entry, _super);

    function Entry() {
      Entry.__super__.constructor.apply(this, arguments);
    }

    Entry.prototype.load = function(eid) {
      var df,
        _this = this;
      df = jQuery.Deferred();
      $.ajax("/" + eid + ".json").fail(function() {
        return df.reject();
      }).done(function(data) {
        _this.set(data);
        return df.resolve(_this);
      });
      return df.promise();
    };

    Entry.prototype.set = function(json) {
      Entry.__super__.set.call(this, json);
      return this.trigger('entries', {
        entries: this.select()
      });
    };

    Entry.prototype.transform = function() {
      var M, d, date, label, n, re, _i, _len, _ref;
      M = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      _ref = ['created', 'updated'];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        label = _ref[_i];
        date = Date.parseISO8601(this.json[label]);
        n = date.getMonth();
        d = date.getDate();
        this.json["" + label + "_n"] = n;
        this.json["" + label + "_d"] = d <= 9 ? "0" + d : d;
        this.json["" + label + "_j"] = d;
        this.json["" + label + "_Y"] = date.getFullYear();
        this.json["" + label + "_M"] = M[n];
      }
      re = new RegExp(decodeURI("%C2%A0"), "g");
      return this.json.html = window.markdown.toHTML(this.json.markdown.replace(re, " "));
    };

    return Entry;

  })(Domino.Model);

  Domino.View.Recent = (function(_super) {

    __extends(Recent, _super);

    function Recent() {
      Recent.__super__.constructor.apply(this, arguments);
    }

    Recent.prototype.subject = "#recent_posts";

    return Recent;

  })(Domino.View.Template);

  Domino.View.Archives = (function(_super) {

    __extends(Archives, _super);

    function Archives() {
      Archives.__super__.constructor.apply(this, arguments);
    }

    Archives.prototype.subject = "div:has(>article>div#blog-archives)";

    return Archives;

  })(Domino.View.Template);

  Domino.View.Index = (function(_super) {

    __extends(Index, _super);

    function Index() {
      Index.__super__.constructor.apply(this, arguments);
    }

    Index.prototype.subject = ".blog-index";

    return Index;

  })(Domino.View.Template);

  Domino.View.Entry = (function(_super) {

    __extends(Entry, _super);

    function Entry() {
      Entry.__super__.constructor.apply(this, arguments);
    }

    Entry.prototype.subject = "#entry";

    return Entry;

  })(Domino.View.Template);

  Domino.View.Loading = (function(_super) {

    __extends(Loading, _super);

    function Loading() {
      Loading.__super__.constructor.apply(this, arguments);
    }

    Loading.prototype.subject = "#loading";

    return Loading;

  })(Domino.View);

  Domino.View.Error = (function(_super) {

    __extends(Error, _super);

    function Error() {
      Error.__super__.constructor.apply(this, arguments);
    }

    Error.prototype.subject = "#error";

    return Error;

  })(Domino.View);

  app = new Domino.Controller;

  app.set_view('index', Domino.View.Index);

  app.set_view('entry', Domino.View.Entry, function() {
    var _this = this;
    return {
      render_after: function() {
        _this.view('entry').el.find("a").each(function() {
          var ext, href;
          href = $(this).attr('href');
          if (!href.match(/\.([^./]+)$/)) return true;
          ext = RegExp.$1;
          switch (ext) {
            case "mp4":
            case "ogg":
            case "m4v":
              return $(this).replaceWith("<video src='" + href + "' controls></video>");
          }
        });
        if (typeof twttr !== "undefined" && twttr !== null) {
          twttr.widgets.load();
        } else {
          jQuery.getScript("http://platform.twitter.com/widgets.js");
        }
        if (typeof DISQUS !== "undefined" && DISQUS !== null) {
          try {
            return DISQUS.reset({
              reload: true,
              config: function() {
                this.page.identifier = location.pathname.substr(1);
                return this.page.url = location.href;
              }
            });
          } catch (e) {
            return console.log(e);
          }
        } else if ((_this.config.disqus != null) && 1 <= _this.config.disqus.length) {
          window.disqus_shortname = _this.config.disqus;
          window.disqus_identifier = location.pathname.substr(1);
          window.disqus_url = location.href;
          return jQuery.getScript("http://" + _this.config.disqus + ".disqus.com/embed.js", function() {
            return window.DISQUS = DISQUS;
          });
        }
      }
    };
  });

  app.set_view('archives', Domino.View.Archives);

  app.set_view('recent', Domino.View.Recent);

  app.set_view('loading', Domino.View.Loading);

  app.set_view('error', Domino.View.Error);

  app.set_model('meta', Domino.Model.Meta);

  app.set_model('index', Domino.Model.Index, function() {
    var _this = this;
    return {
      pager: function(data) {
        return _this.view('index').build(data);
      },
      recent: function(data) {
        return _this.view('recent').build(data);
      },
      entries: function(data) {
        return _this.view('index').build(data);
      },
      archives: function(data) {
        return _this.view('archives').build(data);
      },
      nav: function(data) {
        return _this.view('entry').build(data);
      }
    };
  });

  app.set_model('entry', Domino.Model.Entry, function() {
    var _this = this;
    return {
      refresh: function(data) {
        return _this.view('entry').build(data, 'entry');
      }
    };
  });

  app.binding(function() {
    var _this = this;
    jQuery(document.body).on('click', 'a', function(event) {
      event.preventDefault();
      return _this.reroute($(event.currentTarget).attr('href'));
    });
    return {
      before_run: function() {
        var name, view, _ref;
        _ref = _this.views;
        for (name in _ref) {
          view = _ref[name];
          view.reset();
        }
        return _this.view('loading').show();
      },
      resolve: function() {
        return _this.view('loading').hide();
      },
      reject: function() {
        return _this.view('error').show();
      },
      binding_after: function() {}
    };
  });

  app.route(/^(?:\/|\/page\/(\d+))$/, function(page) {
    var _this = this;
    return this.model('index').load({
      page: page != null ? page : 1,
      numOfEntry: this.config.num_of_index,
      numOfRecent: this.config.num_of_recent
    }).done(function() {
      _this.view('index').render();
      _this.view('recent').render();
      return _this.trigger('resolve');
    });
  });

  app.route('/archives', function() {
    var _this = this;
    return this.model('index').load({
      archives: true,
      numOfRecent: this.config.num_of_recent
    }).done(function() {
      _this.view('archives').render();
      _this.view('recent').render();
      return _this.trigger('resolve');
    });
  });

  app.route(/^\/([0-9a-zA-Z]{4})$/, function(eid) {
    var _this = this;
    return $.when(this.model('index').load({
      eid: eid,
      numOfRecent: this.config.num_of_recent
    }), this.model('entry').load(eid)).done(function() {
      _this.view('entry').build(location, 'location');
      _this.view('entry').render();
      _this.view('recent').render();
      return _this.trigger('resolve');
    });
  });

  init = history.pushState != null;

  $(window).on('popstate', function() {
    if (init) {
      return init = false;
    } else {
      console.log(new Date);
      return app.run(location.pathname);
    }
  });

  $.ajax('/meta.json').done(function(data) {
    if ((data.twitter != null) && 1 <= data.twitter.length) {
      $ = window.octopress;
      getTwitterFeed(data.twitter, 4, false);
      $ = jQuery;
    }
    app.config = data;
    data.now_Y = (new Date()).getFullYear();
    (new Subak.Template(document.documentElement)).load($.extend(data, location), 'meta');
    return app.run(location.pathname);
  });

}).call(this);
