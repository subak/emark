/*
# Name:    Subak the HTML Template Engine
# Version: 0.2.1
# Author:  Takahashi Hiroyuki
# License: GPL Version 2
*/

if ('undefined' == typeof(Subak)) {
  Subak = {}
}
;
Subak.Template = (function() {

  function Template(doc, opt) {
    var _ref, _ref2;
    this.doc = doc;
    if (opt == null) opt = {};
    if (!(this.doc != null) || !(this.doc.childNodes != null)) {
      throw new TypeError('document must not be null');
    }
    this.resetable = (_ref = (opt['resetable'] != null) && opt['resetable']) != null ? _ref : {
      "true": false
    };
    if (this.resetable) this.replica = this.doc.cloneNode(true);
    this.prefix = (_ref2 = opt['prefix']) != null ? _ref2 : 'data-tpl-';
    this.id = "" + this.prefix + "id";
    this.block = "" + this.prefix + "block";
    this.veil = "" + this.prefix + "veil";
    this.append = "" + this.prefix + "append";
    this.insertBefore = "" + this.prefix + "insert_before";
    this.remove = "" + this.prefix + "remove";
    this.removeIf = "" + this.remove + "-if";
    this.removeIfId = "" + this.remove + "-if-id";
    this.removeEmpty = "" + this.remove + "-empty";
    this.removeEqual = "" + this.remove + "-equal";
    this.removeContain = "" + this.remove + "-contain";
    this.removeStartWith = "" + this.remove + "-start_with";
    this.removeEndWith = "" + this.remove + "-end_with";
    this.removeNotEmpty = "" + this.remove + "-not-empty";
    this.removeNotEqual = "" + this.remove + "-not-equal";
    this.removeNotContain = "" + this.remove + "-not-contain";
    this.removeNotStartWith = "" + this.remove + "-not-start_with";
    this.removeNotEndWith = "" + this.remove + "-not-end_with";
    this.removeIdExist = "" + this.remove + "-id-exist";
    this.removeIdNotExist = "" + this.remove + "-id-not-exist";
    this.removeRegex = "" + this.remove + "-regex";
    this.removeNotRegex = "" + this.remove + "-not-regex";
    this.init_track();
  }

  Template.prototype.init_track = function() {
    this.idNodes = [];
    this.varNodes = [];
    this.blockNodes = [];
    this.veilNodes = [];
    this.removeNodes = [];
    this.removeIfNodes = [];
    this.removeIfIdNodes = [];
    this.insertBeforeNodes = [];
    this.appendNodes = [];
    return this.valueNodes = [];
  };

  Template.prototype.track_node = function(node, type) {
    var exists, nodes, _i, _len, _node;
    switch (type) {
      case 'id':
        nodes = this.idNodes;
        break;
      case 'var':
        nodes = this.varNodes;
        break;
      case 'block':
        nodes = this.blockNodes;
        break;
      case 'veil':
        nodes = this.veilNodes;
        break;
      case 'remove':
        nodes = this.removeNodes;
        break;
      case 'remove-if':
        nodes = this.removeIfNodes;
        break;
      case 'remove-if-id':
        nodes = this.removeIfIdNodes;
        break;
      case 'insert_before':
        nodes = this.insertBeforeNodes;
        break;
      case 'append':
        nodes = this.appendNodes;
        break;
      default:
        throw new TypeError('unknown type');
    }
    exists = false;
    for (_i = 0, _len = nodes.length; _i < _len; _i++) {
      _node = nodes[_i];
      if (_node === node) {
        exists = true;
        break;
      }
    }
    if (!exists) return nodes.push(node);
  };

  Template.prototype.reset = function() {
    var attr, doc, _i, _len, _ref, _results;
    if (!this.resetable) throw new Error('this template not allow to reset');
    if (!(this.doc.parentNode != null)) {
      throw new Error('this template can not reset');
    }
    doc = this.replica.cloneNode(true);
    while (this.doc.attributes[0] != null) {
      this.doc.removeAttribute(this.doc.attributes[0].nodeName);
    }
    _ref = doc.attributes;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      attr = _ref[_i];
      this.doc.setAttribute(attr.nodeName, attr.nodeValue);
    }
    while (this.doc.childNodes[0] != null) {
      this.doc.removeChild(this.doc.childNodes[0]);
    }
    _results = [];
    while (doc.childNodes[0] != null) {
      _results.push(this.doc.appendChild(doc.childNodes[0]));
    }
    return _results;
  };

  Template.prototype.load = function(data, namespace) {
    if (namespace == null) namespace = null;
    if (!(data != null)) throw new TypeError('data must not be null');
    this.ns = namespace;
    if ("[object String]" === Object.prototype.toString.call(this.ns)) {
      if (0 === this.ns.length) throw new TypeError('namespace must not be empty');
    }
    this.varsStack = [];
    return this.template(this.doc, data);
  };

  Template.prototype.close = function() {
    var a, b, child, div, existId, html, id, node, parent, res, _i, _j, _k, _l, _len, _len10, _len11, _len2, _len3, _len4, _len5, _len6, _len7, _len8, _len9, _m, _n, _o, _p, _q, _r, _ref, _ref10, _ref11, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9, _s;
    _ref = this.valueNodes;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      node = _ref[_i];
      node.nodeValue = node.nodeValue.replace(/\$\{[^}]*\}/g, '');
    }
    _ref2 = this.appendNodes;
    for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
      node = _ref2[_j];
      if ((html = node.getAttribute(this.append)) && html !== '') {
        div = node.ownerDocument.createElement('div');
        div.innerHTML = html;
        while (div.childNodes[0] != null) {
          node.appendChild(div.childNodes[0]);
        }
        delete div;
        node.removeAttribute(this.append);
      }
    }
    _ref3 = this.insertBeforeNodes;
    for (_k = 0, _len3 = _ref3.length; _k < _len3; _k++) {
      node = _ref3[_k];
      if ((html = node.getAttribute(this.insertBefore))) {
        div = node.ownerDocument.createElement('div');
        div.innerHTML = html;
        _ref4 = div.childNodes;
        for (_l = 0, _len4 = _ref4.length; _l < _len4; _l++) {
          child = _ref4[_l];
          node.parentNode.insertBefore(child, node);
        }
        delete div;
        node.removeAttribute(this.insertBefore);
      }
    }
    _ref5 = this.blockNodes;
    for (_m = 0, _len5 = _ref5.length; _m < _len5; _m++) {
      node = _ref5[_m];
      if ((node.getAttributeNode(this.block) != null) && (node.parentNode != null)) {
        node.parentNode.removeChild(node);
      }
    }
    _ref6 = this.varNodes;
    for (_n = 0, _len6 = _ref6.length; _n < _len6; _n++) {
      node = _ref6[_n];
      parent = node;
      while (parent.parentNode != null) {
        parent.removeAttribute(this.veil);
        if (parent === this.doc) break;
        parent = parent.parentNode;
      }
    }
    _ref7 = this.veilNodes;
    for (_o = 0, _len7 = _ref7.length; _o < _len7; _o++) {
      node = _ref7[_o];
      if ((node.getAttributeNode(this.veil) != null) && (node.parentNode != null)) {
        node.parentNode.removeChild(node);
      }
    }
    _ref8 = this.removeIfNodes;
    for (_p = 0, _len8 = _ref8.length; _p < _len8; _p++) {
      node = _ref8[_p];
      a = node.getAttribute(this.removeIf) || '';
      node.removeAttribute(this.removeIf);
      res = node.getAttributeNode(this.removeEmpty) != null ? (b = node.getAttribute(this.removeEmpty) || '', node.removeAttribute(this.removeEmpty), a.length === 0) : node.getAttributeNode(this.removeNotEmpty) != null ? (b = node.getAttribute(this.removeNotEmpty) || '', node.removeAttribute(this.removeNotEmpty), a.length > 0) : node.getAttributeNode(this.removeEqual) != null ? (b = node.getAttribute(this.removeEqual) || '', node.removeAttribute(this.removeEqual), a === b) : node.getAttributeNode(this.removeNotEqual) != null ? (b = node.getAttribute(this.removeNotEqual) || '', node.removeAttribute(this.removeNotEqual), a !== b) : node.getAttributeNode(this.removeContain) != null ? (b = node.getAttribute(this.removeContain) || '', node.removeAttribute(this.removeContain), a.indexOf(b) >= 0) : node.getAttributeNode(this.removeNotContain) != null ? (b = node.getAttribute(this.removeNotContain) || '', node.removeAttribute(this.removeNotContain), a.indexOf(b) <= -1) : node.getAttributeNode(this.removeStartWith) != null ? (b = node.getAttribute(this.removeStartWith) || '', node.removeAttribute(this.removeStartWith), a.indexOf(b) === 0) : node.getAttributeNode(this.removeNotStartWith) != null ? (b = node.getAttribute(this.removeNotStartWith) || '', node.removeAttribute(this.removeNotStartWith), a.indexOf(b) !== 0) : node.getAttributeNode(this.removeEndWith) != null ? (b = node.getAttribute(this.removeEndWith) || '', node.removeAttribute(this.removeEndWith), res = a.lastIndexOf(b), res >= 0 && a.length - b.length === a.lastIndexOf(b)) : node.getAttributeNode(this.removeNotEndWith) != null ? (b = node.getAttribute(this.removeNotEndWith) || '', node.removeAttribute(this.removeNotEndWith), res = a.lastIndexOf(b), res < 0 || (a.length - b.length) !== a.lastIndexOf(b)) : void 0;
      if (res && (node.parentNode != null)) node.parentNode.removeChild(node);
    }
    existId = {};
    _ref9 = this.idNodes;
    for (_q = 0, _len9 = _ref9.length; _q < _len9; _q++) {
      node = _ref9[_q];
      existId[node.getAttribute(this.id)] |= node.parentNode != null;
    }
    _ref10 = this.removeIfIdNodes;
    for (_r = 0, _len10 = _ref10.length; _r < _len10; _r++) {
      node = _ref10[_r];
      id = node.getAttribute(this.removeIfId);
      node.removeAttribute(this.removeIfId);
      if (node.getAttributeNode(this.removeIdExist)) {
        res = (existId[id] != null) && existId[id];
        node.removeAttribute(this.removeIdExist);
      } else if (node.getAttributeNode(this.removeIdNotExist)) {
        res = !(existId[id] != null) || !existId[id];
        node.removeAttribute(this.removeIdNotExist);
      }
      if (res && (node.parentNode != null)) node.parentNode.removeChild(node);
    }
    _ref11 = this.removeNodes;
    for (_s = 0, _len11 = _ref11.length; _s < _len11; _s++) {
      node = _ref11[_s];
      if (node.parentNode != null) node.parentNode.removeChild(node);
    }
    return this.init_track();
  };

  Template.prototype.template = function(doc, data, previous_vars) {
    var attr, blockname, blocks, child, data_blocks, data_vars, datas, i, job, jobAdded, key, kipple, match, matches, newVars, node, nodes, parentVars, re, stack, tpl, value, varname, varnames, vars, _i, _j, _k, _l, _len, _len10, _len11, _len2, _len3, _len4, _len5, _len6, _len7, _len8, _len9, _m, _n, _o, _p, _q, _r, _ref, _ref2, _ref3, _ref4, _ref5;
    vars = {};
    blocks = {};
    stack = [];
    stack.push({
      node: doc,
      i: 0
    });
    while (stack[0] != null) {
      jobAdded = false;
      job = stack.pop();
      while (job.node.childNodes[job.i] != null) {
        child = job.node.childNodes[job.i];
        switch (child.nodeType) {
          case 3:
            if (matches = child.nodeValue.match(/\$\{[^}]+\}/g)) {
              for (_i = 0, _len = matches.length; _i < _len; _i++) {
                match = matches[_i];
                if (!(vars[match] != null)) vars[match] = [];
                vars[match].push(child);
                this.valueNodes.push(child);
              }
            }
            break;
          case 1:
            if (child.getAttributeNode(this.id) != null) {
              this.track_node(child, 'id');
            }
            if (child.getAttributeNode(this.veil) != null) {
              this.track_node(child, 'veil');
            }
            if (child.getAttributeNode(this.remove) != null) {
              this.track_node(child, 'remove');
            }
            if (child.getAttributeNode(this.removeIf) != null) {
              this.track_node(child, 'remove-if');
            }
            if (child.getAttributeNode(this.removeIfId) != null) {
              this.track_node(child, 'remove-if-id');
            }
            if (child.getAttributeNode(this.insertBefore) != null) {
              this.track_node(child, 'insert_before');
            }
            if (child.getAttributeNode(this.append) != null) {
              this.track_node(child, 'append');
            }
            blockname = child.getAttribute('data-tpl-block');
            if ((blockname != null) && '' !== blockname.length) {
              if (!(blocks[blockname] != null)) blocks[blockname] = [];
              blocks[blockname].push(child);
              this.track_node(child, 'block');
            } else {
              _ref = child.attributes;
              for (_j = 0, _len2 = _ref.length; _j < _len2; _j++) {
                attr = _ref[_j];
                if (matches = attr.nodeValue.match(/\$\{[^}]+\}/g)) {
                  for (_k = 0, _len3 = matches.length; _k < _len3; _k++) {
                    match = matches[_k];
                    if (!(vars[match] != null)) vars[match] = [];
                    vars[match].push(attr);
                    this.valueNodes.push(attr);
                  }
                }
              }
              jobAdded = (_ref2 = 1 <= child.childNodes.length) != null ? _ref2 : {
                "true": false
              };
              if (jobAdded) {
                job.i++;
                stack.push(job);
                stack.push({
                  node: child,
                  i: 0
                });
                break;
              }
            }
        }
        if (jobAdded) break;
        job.i++;
      }
    }
    _ref3 = doc.attributes;
    for (_l = 0, _len4 = _ref3.length; _l < _len4; _l++) {
      attr = _ref3[_l];
      if (matches = attr.nodeValue.match(/\$\{[^}]+\}/g)) {
        for (_m = 0, _len5 = matches.length; _m < _len5; _m++) {
          match = matches[_m];
          if (!(vars[match] != null)) vars[match] = [];
          vars[match].push(attr);
          this.valueNodes.push(attr);
        }
      }
    }
    if (doc.getAttributeNode(this.id) != null) this.track_node(doc, 'id');
    if (doc.getAttributeNode(this.veil) != null) this.track_node(doc, 'veil');
    if (doc.getAttributeNode(this.remove) != null) this.track_node(doc, 'remove');
    if (doc.getAttributeNode(this.removeIf) != null) {
      this.track_node(doc, 'remove-if');
    }
    if (doc.getAttributeNode(this.removeIfId) != null) {
      this.track_node(doc, 'remove-if-id');
    }
    if (doc.getAttributeNode(this.insertBefore) != null) {
      this.track_node(doc, 'insert_before');
    }
    if (doc.getAttributeNode(this.append) != null) this.track_node(doc, 'append');
    data_vars = {};
    data_blocks = {};
    for (key in data) {
      value = data[key];
      switch (Object.prototype.toString.call(value)) {
        case '[object Array]':
          data_blocks[key] = value;
          break;
        case '[object Number]':
        case '[object String]':
        case '[object Boolean]':
        case '[object Null]':
        case '[object Undefined]':
          data_vars[key] = value != null ? value : "";
          break;
        default:
          data_blocks[key] = [value];
      }
    }
    newVars = {};
    i = 1;
    _ref4 = this.varsStack.reverse();
    for (_n = 0, _len6 = _ref4.length; _n < _len6; _n++) {
      parentVars = _ref4[_n];
      for (key in parentVars) {
        value = parentVars[key];
        for (kipple = 0; 0 <= i ? kipple <= i : kipple >= i; 0 <= i ? kipple++ : kipple--) {
          key = "@" + key;
        }
        newVars[key] = value;
      }
      i += 1;
    }
    this.varsStack.reverse();
    _ref5 = this.varsStack;
    for (_o = 0, _len7 = _ref5.length; _o < _len7; _o++) {
      parentVars = _ref5[_o];
      for (key in parentVars) {
        value = parentVars[key];
        newVars[key] = value;
      }
    }
    for (key in data_vars) {
      value = data_vars[key];
      newVars[key] = value;
      newVars["@" + key] = value;
    }
    if (previous_vars != null) {
      for (key in previous_vars) {
        value = previous_vars[key];
        newVars["#" + key] = value;
      }
    }
    for (varname in newVars) {
      data = newVars[varname];
      varnames = [varname];
      if (this.ns != null) varnames.push("" + this.ns + ":" + varname);
      for (_p = 0, _len8 = varnames.length; _p < _len8; _p++) {
        varname = varnames[_p];
        if (nodes = vars["${" + varname + "}"]) {
          varname = '\\$\\{' + varname + '\\}';
          for (_q = 0, _len9 = nodes.length; _q < _len9; _q++) {
            node = nodes[_q];
            re = new RegExp(varname, 'g');
            node.nodeValue = node.nodeValue.replace(re, data);
            if (node.nodeType === 2) this.track_node(node.ownerElement, 'var');
            if (node.nodeType === 3) this.track_node(node.parentNode, 'var');
          }
        }
      }
    }
    for (blockname in data_blocks) {
      datas = data_blocks[blockname];
      if (nodes = blocks[blockname]) {
        for (_r = 0, _len10 = nodes.length; _r < _len10; _r++) {
          node = nodes[_r];
          previous_vars = null;
          for (i = 0, _len11 = datas.length; i < _len11; i++) {
            data = datas[i];
            tpl = node.cloneNode(true);
            data_vars['_i'] = i;
            this.varsStack.push(data_vars);
            previous_vars = this.template(tpl, data, previous_vars);
            this.varsStack.pop();
            tpl.removeAttribute('data-tpl-block');
            node.parentNode.insertBefore(tpl, node);
          }
        }
      }
    }
    return data_vars;
  };

  return Template;

})();
