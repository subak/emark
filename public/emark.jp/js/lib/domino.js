
/*
# Name:    Domino the MVC Framework
# Version: 0.1.1
# Author:  Takahashi Hiroyuki
# License: GPL Version 2
# @depend: jQuery
*/

(function() {
  
if ('undefined' == typeof(Domino)) {
  Domino = {}
}
;
  var __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  Domino.Model = (function() {

    Model.prototype.binds = null;

    Model.prototype.initialize = function() {};

    function Model(json) {
      this.json = json;
      this.binds = {};
      this.initialize();
    }

    Model.prototype.select = function() {
      return this.json;
    };

    Model.prototype.set = function(json) {
      this.json = json;
      this.transform();
      this.trigger('change', this.select());
      return this.trigger('refresh', this.select());
    };

    Model.prototype.toJson = function() {
      return this.json;
    };

    Model.prototype.transform = function() {
      return this;
    };

    Model.prototype.bind = function(event, handler) {
      if (!(this.binds[event] != null)) this.binds[event] = [];
      return this.binds[event].push(handler);
    };

    Model.prototype.trigger = function(event, data) {
      var handler, _i, _len, _ref, _results;
      if (data == null) data = null;
      if (this.binds[event] != null) {
        _ref = this.binds[event];
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          handler = _ref[_i];
          _results.push(handler(data));
        }
        return _results;
      }
    };

    Model.prototype.unbind = function() {
      return this.binds = {};
    };

    return Model;

  })();

  Domino.View = (function() {

    View.prototype.subject = null;

    View.prototype.el = null;

    View.prototype.binds = null;

    View.prototype.build = function() {};

    View.prototype.events = function() {};

    function View() {
      this.binds = {};
      this.initialize();
      this.events();
    }

    View.prototype.initialize = function() {
      return this.el = jQuery(this.subject);
    };

    View.prototype.show = function() {
      return this.el.show();
    };

    View.prototype.hide = function() {
      return this.el.hide();
    };

    View.prototype.render = function() {
      this.trigger('render_before');
      this.show();
      return this.trigger('render_after');
    };

    View.prototype.reset = function() {
      this.trigger('reset_before');
      this.hide();
      return this.trigger('reset_after');
    };

    View.prototype.bind = function(event, handler) {
      if (!(this.binds[event] != null)) this.binds[event] = [];
      return this.binds[event].push(handler);
    };

    View.prototype.trigger = function(event, data) {
      var handler, _i, _len, _ref, _results;
      if (data == null) data = null;
      if (this.binds[event] != null) {
        _ref = this.binds[event];
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          handler = _ref[_i];
          _results.push(handler(data));
        }
        return _results;
      }
    };

    View.prototype.unbind = function() {
      return this.binds = {};
    };

    return View;

  })();

  Domino.View.Template = (function(_super) {

    __extends(Template, _super);

    function Template() {
      Template.__super__.constructor.apply(this, arguments);
    }

    Template.prototype.initialize = function() {
      Template.__super__.initialize.call(this);
      return this.tpl = new Subak.Template(jQuery(this.subject).get(0), {
        resetable: true
      });
    };

    Template.prototype.build = function(data, namespace) {
      if (data == null) data = {};
      if (namespace == null) namespace = null;
      this.trigger('build_before');
      this.tpl.load(data, namespace);
      return this.trigger('build_after');
    };

    Template.prototype.render = function() {
      this.trigger('render_before');
      this.tpl.close();
      this.show();
      return this.trigger('render_after');
    };

    Template.prototype.reset = function() {
      this.trigger('reset_before');
      this.tpl.reset();
      this.el = jQuery(this.subject);
      this.hide();
      return this.trigger('reset_after');
    };

    return Template;

  })(Domino.View);

  Domino.Controller = (function() {

    Controller.popstate = function(process) {
      var init, run;
      run = function() {
        jQuery(window).on('popstate', function() {
          return process();
        });
        return jQuery(window).trigger('popstate');
      };
      if (history.pushState != null) {
        init = function() {
          jQuery(window).off('popstate', init);
          return run();
        };
        return jQuery(window).on('popstate', init);
      } else {
        return run();
      }
    };

    Controller.prototype.initial = null;

    Controller.prototype.routes = null;

    Controller.prototype.procs = null;

    Controller.prototype.binds = null;

    Controller.prototype.views = null;

    Controller.prototype.models = null;

    Controller.prototype.bindings = null;

    function Controller() {
      this.initial = true;
      this.routes = [];
      this.procs = [];
      this.binds = {};
      this.views = [];
      this.models = [];
      this.bindings = [];
    }

    Controller.prototype.route = function(route, proc) {
      this.routes.push(route);
      return this.procs.push(proc);
    };

    Controller.prototype.reroute = function(route, push) {
      if (push == null) push = true;
      if ((history.pushState != null) && !route.match(/^https?/)) {
        return this.run(route, true, push);
      } else {
        return window.open(route, "_blank");
      }
    };

    Controller.prototype.bind = function(event, handler) {
      if (!(this.binds[event] != null)) this.binds[event] = [];
      return this.binds[event].push(handler);
    };

    Controller.prototype.trigger = function(event, data) {
      var handler, _i, _len, _ref, _results;
      if (data == null) data = null;
      if (this.binds[event] != null) {
        _ref = this.binds[event];
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          handler = _ref[_i];
          _results.push(handler(data));
        }
        return _results;
      }
    };

    Controller.prototype.binding = function(binding) {
      if (binding == null) binding = function() {};
      return this.bindings.push(function() {
        var bindings, event, handler, _results;
        bindings = binding.apply(this);
        _results = [];
        for (event in bindings) {
          handler = bindings[event];
          _results.push(this.bind(event, handler));
        }
        return _results;
      });
    };

    Controller.prototype.view = function(name) {
      return this.views[name];
    };

    Controller.prototype.model = function(name) {
      return this.models[name];
    };

    Controller.prototype.set_model = function(name, Model, bindings) {
      if (bindings == null) bindings = function() {};
      return this.bindings.push(function() {
        var event, handler, model;
        model = new Model;
        bindings = bindings.apply(this);
        for (event in bindings) {
          handler = bindings[event];
          model.bind(event, handler);
        }
        return this.models[name] = model;
      });
    };

    Controller.prototype.set_view = function(name, View, bindings) {
      if (bindings == null) bindings = function() {};
      return this.bindings.push(function() {
        var event, handler, view;
        view = new View;
        bindings = bindings.apply(this);
        for (event in bindings) {
          handler = bindings[event];
          view.bind(event, handler);
        }
        return this.views[name] = view;
      });
    };

    Controller.prototype.run = function(path, state, push) {
      var binding, capture, captures, found, i, n, onerror, re, route, _i, _len, _len2, _ref, _ref2,
        _this = this;
      if (state == null) state = false;
      if (push == null) push = true;
      onerror = function(event) {
        jQuery(window).unbind('error');
        _this.trigger('reject');
        console.log(event);
        return alert(event);
      };
      jQuery(window).bind('error', onerror);
      if (this.initial) {
        _ref = this.bindings;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          binding = _ref[_i];
          binding.apply(this);
        }
        this.trigger("binding_after");
        this.initial = false;
      }
      found = false;
      _ref2 = this.routes;
      for (i = 0, _len2 = _ref2.length; i < _len2; i++) {
        route = _ref2[i];
        if (!(route instanceof RegExp)) {
          if (route === path) {
            if (state) {
              if (push) {
                history.pushState(null, null, path);
              } else {
                history.replaceState(null, null, path);
              }
            }
            this.trigger('before_run');
            this.trigger('before');
            this.trigger('started');
            this.procs[i].apply(this);
            found = true;
            break;
          }
          re = route.replace(/\/:[^/]+/g, '/([^/]+)');
          if (re === route) continue;
          re = re.replace(/\//g, '\\/');
          re = "^" + re + "$";
          route = RegExp(re, 'g');
        }
        if (route.exec(path)) {
          if (state) {
            if (push) {
              history.pushState(null, null, path);
            } else {
              history.replaceState(null, null, path);
            }
          }
          captures = [];
          n = 1;
          while (capture = RegExp['$' + n]) {
            captures.push(capture);
            n++;
          }
          this.trigger('before_run');
          this.trigger('before');
          this.trigger('started');
          this.procs[i].apply(this, captures);
          found = true;
          break;
        }
      }
      if (!found) return location.href = path;
    };

    return Controller;

  })();

}).call(this);
