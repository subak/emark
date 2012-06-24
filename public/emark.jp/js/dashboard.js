(function() {
  var app, init,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  jQuery.ajaxSetup({
    cache: false
  });

  Domino.Model.Blogs = (function(_super) {

    __extends(Blogs, _super);

    function Blogs() {
      Blogs.__super__.constructor.apply(this, arguments);
    }

    Blogs.prototype.load = function() {
      var df,
        _this = this;
      df = jQuery.Deferred();
      df.fail(function() {
        return _this.trigger('load_fail');
      });
      df.done(function() {
        return _this.trigger('load_done');
      });
      jQuery.ajax("/dashboard").fail(function() {
        return df.reject();
      }).pipe(function(json) {
        _this.set(json);
        return df.resolve(_this);
      });
      return df.promise();
    };

    Blogs.prototype.remove = function(blogid) {
      var df,
        _this = this;
      df = jQuery.Deferred();
      df.fail(function() {
        return _this.trigger('remove_fail');
      });
      df.done(function() {
        return _this.trigger('remove_done');
      });
      jQuery.ajax({
        url: "/close/" + blogid,
        type: "DELETE"
      }).fail(function() {
        return df.reject();
      }).pipe(function(json) {
        return df.resolve(json);
      });
      return df.promise();
    };

    return Blogs;

  })(Domino.Model);

  Domino.Model.Publish = (function(_super) {

    __extends(Publish, _super);

    function Publish() {
      Publish.__super__.constructor.apply(this, arguments);
    }

    Publish.prototype.load = function() {
      var df,
        _this = this;
      df = jQuery.Deferred();
      df.fail(function() {
        return _this.trigger('load_fail');
      });
      df.done(function() {
        return _this.trigger('load_done');
      });
      jQuery.ajax("/open").fail(function() {
        return df.reject();
      }).pipe(function(json) {
        _this.set(json);
        return df.resolve(_this);
      });
      return df.promise();
    };

    Publish.prototype.save = function(data) {
      var df,
        _this = this;
      df = jQuery.Deferred();
      df.fail(function() {
        return _this.trigger('save_error');
      });
      df.done(function() {
        return _this.trigger('save_after');
      });
      jQuery.ajax({
        url: "/open",
        type: "POST",
        data: data
      }).fail(function() {
        return df.reject();
      }).done(function() {
        return df.resolve();
      });
      this.trigger('save_before');
      return df.promise();
    };

    Publish.prototype.check = function(blogid) {
      var df,
        _this = this;
      df = jQuery.Deferred();
      df.fail(function() {
        return _this.trigger('check_error');
      });
      df.done(function(data) {
        if (data.available) {
          _this.trigger('check_ok');
        } else {
          _this.trigger('check_ng');
        }
        return _this.trigger('check_after', data);
      });
      jQuery.ajax({
        url: "/check/blogid/" + blogid,
        type: "GET"
      }).fail(function() {
        return df.reject();
      }).done(function(data) {
        return df.resolve(data);
      });
      this.trigger('check_before');
      return df.promise();
    };

    return Publish;

  })(Domino.Model);

  Domino.Model.Config = (function(_super) {

    __extends(Config, _super);

    function Config() {
      Config.__super__.constructor.apply(this, arguments);
    }

    Config.prototype.load = function(blogid) {
      var df,
        _this = this;
      df = jQuery.Deferred();
      df.fail(function() {
        return _this.trigger('load_fail');
      });
      df.done(function() {
        return _this.trigger('load_done');
      });
      jQuery.ajax("/config/" + blogid).fail(function() {
        return df.reject();
      }).pipe(function(json) {
        _this.set(json);
        return df.resolve(_this);
      });
      return df.promise();
    };

    Config.prototype.save = function(blogid, data) {
      var df,
        _this = this;
      df = jQuery.Deferred();
      df.fail(function() {
        return _this.trigger('error_save');
      });
      df.done(function() {
        return _this.trigger('after_save');
      });
      jQuery.ajax({
        url: "/config/" + blogid,
        type: "PUT",
        data: data
      }).fail(function() {
        return df.reject();
      }).done(function() {
        return df.resolve();
      });
      this.trigger('before_save');
      return df.promise();
    };

    return Config;

  })(Domino.Model);

  Domino.View.Root = (function(_super) {

    __extends(Root, _super);

    function Root() {
      Root.__super__.constructor.apply(this, arguments);
    }

    Root.prototype.subject = 'body';

    Root.prototype.show = function() {};

    Root.prototype.hide = function() {};

    Root.prototype.events = function() {
      var _this = this;
      return this.el.on('click', "a[href='/logout']", function(event) {
        event.preventDefault();
        return _this.trigger('logout');
      });
    };

    return Root;

  })(Domino.View);

  Domino.View.Error = (function(_super) {

    __extends(Error, _super);

    function Error() {
      Error.__super__.constructor.apply(this, arguments);
    }

    Error.prototype.subject = "#error";

    return Error;

  })(Domino.View);

  Domino.View.Loading = (function(_super) {

    __extends(Loading, _super);

    function Loading() {
      Loading.__super__.constructor.apply(this, arguments);
    }

    Loading.prototype.subject = "#loading";

    Loading.prototype.show = function() {
      return this.el.fadeIn();
    };

    Loading.prototype.hide = function() {
      return this.el.fadeOut();
    };

    return Loading;

  })(Domino.View);

  Domino.View.IndexContainer = (function(_super) {

    __extends(IndexContainer, _super);

    function IndexContainer() {
      IndexContainer.__super__.constructor.apply(this, arguments);
    }

    IndexContainer.prototype.subject = "#index-container";

    IndexContainer.prototype.show = function() {
      return this.el.fadeIn();
    };

    IndexContainer.prototype.events = function() {
      var danger, edit, editDanger, editSuccess, open, success,
        _this = this;
      this.el.on('click', "a[href^='/close']", function(event) {
        event.preventDefault();
        if (!confirm($(event.currentTarget).attr("data-msg"))) {
          return event.stopImmediatePropagation();
        }
      });
      this.el.on('click', "a[data-state]", function(event) {
        event.preventDefault();
        return _this.trigger('action', $(event.currentTarget));
      });
      open = "#open-blog";
      edit = "#edit-blogs";
      editSuccess = ".btn-success";
      editDanger = ".btn-danger";
      success = ".edit-success";
      danger = ".edit-danger";
      this.bind('render_after', function() {
        if (0 !== _this.el.find(".blogs").size()) {
          _this.el.find(edit).removeClass('hidden');
          _this.el.find(edit).find(editSuccess).hide();
          return _this.el.find(danger).hide();
        }
      });
      return this.el.on('click', edit, function(event) {
        var button;
        button = $(event.currentTarget);
        if (!button.find(editDanger).is(":hidden")) {
          _this.el.find(open).slideUp();
          return button.find(editDanger).slideUp(function() {
            _this.el.find(success).slideUp();
            _this.el.find(danger).slideDown();
            return button.find(editSuccess).slideDown();
          });
        } else {
          return button.find(editSuccess).slideUp(function() {
            _this.el.find(open).slideDown();
            _this.el.find(success).slideDown();
            _this.el.find(danger).slideUp();
            return button.find(editDanger).slideDown();
          });
        }
      });
    };

    return IndexContainer;

  })(Domino.View.Template);

  Domino.View.Sync = (function(_super) {

    __extends(Sync, _super);

    function Sync() {
      Sync.__super__.constructor.apply(this, arguments);
    }

    Sync.prototype.subject = "#sync";

    Sync.prototype.show = function() {
      return this.el.modal('show');
    };

    Sync.prototype.hide = function() {
      return this.el.modal('hide');
    };

    Sync.prototype.events = function() {
      var _this = this;
      return this.el.on("hidden", function() {
        return _this.trigger("hidden");
      });
    };

    return Sync;

  })(Domino.View.Template);

  Domino.View.ConfigModal = (function(_super) {

    __extends(ConfigModal, _super);

    function ConfigModal() {
      ConfigModal.__super__.constructor.apply(this, arguments);
    }

    ConfigModal.prototype.subject = "#config-modal";

    ConfigModal.prototype.show = function() {
      return this.el.modal('show');
    };

    ConfigModal.prototype.hide = function() {
      return this.el.modal('hide');
    };

    ConfigModal.prototype.events = function() {
      var _this = this;
      this.bind("render_after", function() {
        return _this.el.find("select[data-range]").each(function() {
          var $select, i, _ref, _ref2;
          $select = $(this);
          for (i = _ref = parseInt($select.attr("data-min"), 10), _ref2 = parseInt($select.attr("data-max"), 10); _ref <= _ref2 ? i <= _ref2 : i >= _ref2; _ref <= _ref2 ? i++ : i--) {
            $select.append("<option value='" + i + "'>" + i + "</option>");
          }
          return $select.val($select.attr("data-value"));
        });
      });
      this.el.on("click", "a", function(event) {
        event.preventDefault();
        return $(event.currentTarget).tab('show');
      });
      this.el.on('hidden', function(event) {
        return _this.trigger('hidden', event);
      });
      return this.el.on('submit', 'form', function(event) {
        event.preventDefault();
        return _this.trigger('submit', _this.el.find('form').serialize());
      });
    };

    return ConfigModal;

  })(Domino.View.Template);

  Domino.View.PublishContainer = (function(_super) {

    __extends(PublishContainer, _super);

    function PublishContainer() {
      PublishContainer.__super__.constructor.apply(this, arguments);
    }

    PublishContainer.prototype.subject = "#publish-container";

    PublishContainer.prototype.show = function() {
      return this.el.modal('show');
    };

    PublishContainer.prototype.hide = function() {
      return this.el.modal('hide');
    };

    PublishContainer.prototype.events = function() {
      var tid,
        _this = this;
      this.el.on('hidden', function(event) {
        return _this.trigger('hidden', event);
      });
      this.guid = "[name='notebookGuid']";
      this.domain = "[name='domain']";
      this.subdomain = "[name='subdomain']";
      this.submit = "button[type='submit']";
      this.cancel = "button[data-dismiss='modal']";
      this.group = ".control-group";
      this.msgDomainInvalid = "#msg-domain-invalid";
      this.msgDomainDouble = "#msg-domain-double";
      this.msgDomainEmpty = "#msg-domain-empty";
      this.msgConfirm = "#msg-confirm";
      tid = null;
      this.el.on("keyup", "form :text[name='subdomain']", function(event) {
        if (tid != null) clearTimeout(tid);
        return tid = setTimeout(function() {
          var domain, subdomain;
          domain = _this.el.find(_this.domain).val();
          subdomain = event.currentTarget.value;
          if (subdomain.length !== 0) {
            _this.el.find(_this.msgDomainEmpty).addClass('hidden').parents(_this.group).first().removeClass('error');
          }
          if (subdomain.match(/^(([0-9a-z]+[.-])+)?[0-9a-z]+$/) || subdomain.length === 0) {
            _this.el.find(_this.msgDomainInvalid).addClass('hidden').parents(_this.group).first().removeClass('error');
            return _this.trigger('check_blogid', "" + subdomain + "." + domain);
          } else {
            return _this.el.find(_this.msgDomainInvalid).removeClass('hidden').parents(_this.group).first().addClass('error');
          }
        }, 500);
      });
      this.bind('blogid_ok', function() {
        return _this.el.find(_this.msgDomainDouble).addClass('hidden').parents(_this.group).first().removeClass('error');
      });
      this.bind('blogid_ng', function() {
        return _this.el.find(_this.msgDomainDouble).removeClass('hidden').parents(_this.group).first().addClass('error');
      });
      return this.el.on('submit', 'form', function(event) {
        var msg;
        event.preventDefault();
        if (_this.el.find(_this.subdomain).val().length === 0) {
          _this.el.find(_this.msgDomainEmpty).removeClass('hidden').parents(_this.group).first().addClass('error');
        }
        if (!_this.el.find(_this.group).is(".error")) {
          msg = _this.el.find(_this.submit).attr('data-msg-confirm');
          if (confirm(msg)) {
            return _this.trigger('submit', _this.el.find('form').serialize());
          }
        }
      });
    };

    return PublishContainer;

  })(Domino.View.Template);

  app = new Domino.Controller;

  app.set_model('blogs', Domino.Model.Blogs, function() {
    var _this = this;
    return {
      change: function(data) {
        return _this.view('index').build(data);
      },
      load_fail: function() {
        return _this.trigger('reject');
      },
      remove_fail: function() {
        return _this.trigger('reject');
      }
    };
  });

  app.set_model('config', Domino.Model.Config, function() {
    var _this = this;
    return {
      change: function(data) {
        return _this.view('config').build(data);
      },
      load_fail: function() {
        return _this.trigger('reject');
      },
      before_save: function() {
        return _this.view('loading').show();
      },
      after_save: function() {
        return _this.view('config').hide();
      },
      error_save: function() {
        return _this.trigger('reject');
      }
    };
  });

  app.set_model('publish', Domino.Model.Publish, function() {
    var _this = this;
    return {
      change: function(data) {
        return _this.view('publish').build(data);
      },
      load_fail: function() {
        return _this.trigger('reject');
      },
      check_error: function() {
        return _this.trigger('reject');
      },
      check_ok: function() {
        return _this.view('publish').trigger('blogid_ok');
      },
      check_ng: function() {
        return _this.view('publish').trigger('blogid_ng');
      },
      save_error: function() {
        return _this.trigger('reject');
      },
      save_before: function() {
        return _this.view('loading').show();
      },
      save_after: function() {
        return _this.view('publish').hide();
      }
    };
  });

  app.set_view('loading', Domino.View.Loading);

  app.set_view('error', Domino.View.Error);

  app.set_view('root', Domino.View.Root, function() {
    var _this = this;
    return {
      logout: function() {
        return _this.reroute("/logout", false);
      }
    };
  });

  app.set_view('index', Domino.View.IndexContainer, function() {
    var _this = this;
    return {
      action: function(anchor) {
        if (anchor.is("[data-state='push']")) {
          return _this.reroute(anchor.attr("href"));
        } else if (anchor.is("[data-state='replace']")) {
          return _this.reroute(anchor.attr("href"), false);
        }
      }
    };
  });

  app.set_view('publish', Domino.View.PublishContainer, function() {
    var _this = this;
    return {
      hidden: function() {
        return _this.reroute('/dashboard', false);
      },
      check_blogid: function(blogid) {
        return _this.model('publish').check(blogid);
      },
      submit: function(data) {
        return _this.model('publish').save(data);
      }
    };
  });

  app.set_view('config', Domino.View.ConfigModal, function() {
    var _this = this;
    return {
      hidden: function() {
        return _this.reroute('/dashboard', false);
      },
      submit: function(data) {
        var blogid;
        blogid = location.pathname.replace(/^\/config\//, '');
        return _this.model('config').save(blogid, data);
      }
    };
  });

  app.set_view('sync', Domino.View.Sync, function() {
    var _this = this;
    return {
      hidden: function() {
        return _this.reroute('/dashboard', false);
      }
    };
  });

  app.binding(function() {
    var _this = this;
    return {
      before_run: function() {
        var name, view, _ref;
        _ref = _this.views;
        for (name in _ref) {
          view = _ref[name];
          if (name !== 'loading') view.reset();
        }
        return _this.view('loading').show();
      },
      resolve: function() {
        return _this.view('loading').hide();
      },
      reject: function() {
        return _this.view('error').show();
      }
    };
  });

  app.route("/", function() {
    var _this = this;
    return $.ajax({
      url: "/",
      data: location.search.substr(1),
      dataType: 'text'
    }).fail(function() {
      return _this.trigger('reject');
    }).done(function(redirect) {
      return location.href = redirect;
    });
  });

  app.route("/dashboard", function() {
    var _this = this;
    return this.model('blogs').load().done(function() {
      _this.view('index').render();
      return _this.trigger('resolve');
    });
  });

  app.route("/open", function() {
    var _this = this;
    return this.model('publish').load().done(function() {
      _this.view('publish').render();
      return _this.trigger('resolve');
    });
  });

  app.route("/config/:blogid", function(blogid) {
    var _this = this;
    return this.model('config').load(blogid).done(function() {
      _this.view('config').render();
      return _this.trigger('resolve');
    });
  });

  app.route("/sync/:blogid", function(blogid) {
    var _this = this;
    return $.ajax({
      url: "/sync/" + blogid,
      type: "PUT"
    }).fail(function() {
      return _this.trigger('reject');
    }).done(function(data) {
      _this.view('sync').build(data);
      _this.view('sync').render();
      return _this.trigger('resolve');
    });
  });

  app.route("/close/:blogid", function(blogid) {
    var _this = this;
    return this.model('blogs').remove(blogid).done(function() {
      return _this.reroute('/dashboard', false);
    });
  });

  app.route("/logout", function() {
    var _this = this;
    return $.ajax({
      url: "/logout",
      type: "DELETE",
      dataType: "text"
    }).fail(function() {
      return _this.trigger('reject');
    }).done(function(redirect) {
      return location.href = redirect;
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

  $.ajax('/config.json').done(function(json) {
    app.binding(function() {
      var _this = this;
      this.view('publish').bind('render_before', function() {
        return _this.view('publish').build(json, 'config');
      });
      return {
        binding_after: function() {
          var tpl;
          tpl = new Subak.Template(document.documentElement);
          tpl.load(json);
          return tpl.close();
        }
      };
    });
    app.bind("binding_after", function() {
      var tpl;
      tpl = new Subak.Template(document.documentElement);
      tpl.load(json);
      return tpl.close();
    });
    return app.run(location.pathname);
  });

}).call(this);
