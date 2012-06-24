###
# Name:    Subak the HTML Template Engine
# Version: 0.2.1
# Author:  Takahashi Hiroyuki
# License: GPL Version 2
###

`
if ('undefined' == typeof(Subak)) {
  Subak = {}
}
`

class Subak.Template
  constructor: (@doc, opt={}) ->
    throw new TypeError 'document must not be null' if !@doc? or !@doc.childNodes?

    @resetable  = (opt['resetable']? && opt['resetable']) ? true : false
    @replica    = @doc.cloneNode true if @resetable

    @prefix = opt['prefix'] ? 'data-tpl-'

    @id           = "#{@prefix}id"
    @block        = "#{@prefix}block"
    @veil         = "#{@prefix}veil"
    @append       = "#{@prefix}append"
    @insertBefore = "#{@prefix}insert_before"
    @remove       = "#{@prefix}remove"
    @removeIf     = "#{@remove}-if"
    @removeIfId   = "#{@remove}-if-id"

    @removeEmpty     = "#{@remove}-empty"
    @removeEqual     = "#{@remove}-equal"
    @removeContain   = "#{@remove}-contain"
    @removeStartWith = "#{@remove}-start_with"
    @removeEndWith   = "#{@remove}-end_with"

    @removeNotEmpty     = "#{@remove}-not-empty"
    @removeNotEqual     = "#{@remove}-not-equal"
    @removeNotContain   = "#{@remove}-not-contain"
    @removeNotStartWith = "#{@remove}-not-start_with"
    @removeNotEndWith   = "#{@remove}-not-end_with"

    @removeIdExist    = "#{@remove}-id-exist"
    @removeIdNotExist = "#{@remove}-id-not-exist"

    # 未実装
    @removeRegex    = "#{@remove}-regex"
    @removeNotRegex = "#{@remove}-not-regex"

    @init_track()

  init_track: ->
    @idNodes           = []
    @varNodes          = []
    @blockNodes        = []
    @veilNodes         = []
    @removeNodes       = []
    @removeIfNodes     = []
    @removeIfIdNodes   = []
    @insertBeforeNodes = []
    @appendNodes       = []
    @valueNodes        = []

  track_node: (node, type)->
    switch type
      when 'id'            then nodes = @idNodes
      when 'var'           then nodes = @varNodes
      when 'block'         then nodes = @blockNodes
      when 'veil'          then nodes = @veilNodes
      when 'remove'        then nodes = @removeNodes
      when 'remove-if'     then nodes = @removeIfNodes
      when 'remove-if-id'  then nodes = @removeIfIdNodes
      when 'insert_before' then nodes = @insertBeforeNodes
      when 'append'        then nodes = @appendNodes
      else throw new TypeError 'unknown type'

    # 被りを取り除く
    exists = false
    for _node in nodes
      if _node == node
        exists = true
        break

    nodes.push node if !exists

  reset: ->
    throw new Error 'this template not allow to reset' if !@resetable
    # removeやveilによって自分自身が削除されていたらresetできない
    throw new Error 'this template can not reset' if !@doc.parentNode?
    doc = @replica.cloneNode true

    # 属性のコピー 
    while @doc.attributes[0]?
      @doc.removeAttribute @doc.attributes[0].nodeName

    for attr in doc.attributes
      @doc.setAttribute attr.nodeName, attr.nodeValue

    # 子要素のコピー
    while @doc.childNodes[0]?
      @doc.removeChild @doc.childNodes[0]

    while doc.childNodes[0]?
      @doc.appendChild doc.childNodes[0]

  load: (data, namespace=null)->
    throw new TypeError 'data must not be null' if !data?
    @ns = namespace
    if "[object String]" == Object.prototype.toString.call(@ns)
      throw new TypeError 'namespace must not be empty' if 0 == @ns.length

    @varsStack = []
    @template @doc, data

  close: ->

    # 変数の削除
    for node in @valueNodes
      node.nodeValue = node.nodeValue.replace /\$\{[^}]*\}/g, ''

    # append
    for node in @appendNodes
      if (html = node.getAttribute(@append)) and html != ''
        div = node.ownerDocument.createElement 'div'
        div.innerHTML = html
        while div.childNodes[0]?
          node.appendChild div.childNodes[0]
        delete div
        node.removeAttribute @append

    # insertBefore
    for node in @insertBeforeNodes
      if (html = node.getAttribute(@insertBefore))
        div = node.ownerDocument.createElement 'div'
        div.innerHTML = html
        for child in div.childNodes
          node.parentNode.insertBefore child, node
        delete div
        node.removeAttribute @insertBefore

    # touchされなかったblockの削除
    for node in @blockNodes
      node.parentNode.removeChild node if node.getAttributeNode(@block)? and node.parentNode?

    # veil消し 先祖まで遡る
    for node in @varNodes
      parent = node
      while parent.parentNode?
        parent.removeAttribute @veil
        break if parent == @doc
        parent = parent.parentNode

    # veilの残った要素を削除
    for node in @veilNodes
      node.parentNode.removeChild node if node.getAttributeNode(@veil)? and node.parentNode?

    # removeIf
    for node in @removeIfNodes
      a = node.getAttribute(@removeIf) || ''
      node.removeAttribute @removeIf

      res = if node.getAttributeNode(@removeEmpty)?
        b = node.getAttribute(@removeEmpty) || ''
        node.removeAttribute @removeEmpty
        a.length == 0
      else if node.getAttributeNode(@removeNotEmpty)?
        b = node.getAttribute(@removeNotEmpty) || ''
        node.removeAttribute @removeNotEmpty
        a.length > 0
      else if node.getAttributeNode(@removeEqual)?
        b = node.getAttribute(@removeEqual) || ''
        node.removeAttribute @removeEqual
        a is b
      else if node.getAttributeNode(@removeNotEqual)?
        b = node.getAttribute(@removeNotEqual) || ''
        node.removeAttribute @removeNotEqual
        a isnt b
      else if node.getAttributeNode(@removeContain)?
        b = node.getAttribute(@removeContain) || ''
        node.removeAttribute @removeContain
        a.indexOf(b) >= 0
      else if node.getAttributeNode(@removeNotContain)?
        b = node.getAttribute(@removeNotContain) || ''
        node.removeAttribute @removeNotContain
        a.indexOf(b) <= -1
      else if node.getAttributeNode(@removeStartWith)?
        b = node.getAttribute(@removeStartWith) || ''
        node.removeAttribute @removeStartWith
        a.indexOf(b) == 0
      else if node.getAttributeNode(@removeNotStartWith)?
        b = node.getAttribute(@removeNotStartWith) || ''
        node.removeAttribute @removeNotStartWith
        a.indexOf(b) != 0
      else if node.getAttributeNode(@removeEndWith)?
        b = node.getAttribute(@removeEndWith) || ''
        node.removeAttribute @removeEndWith
        res = a.lastIndexOf(b)
        res >= 0 and a.length - b.length is a.lastIndexOf(b)
      else if node.getAttributeNode(@removeNotEndWith)?
        b = node.getAttribute(@removeNotEndWith) || ''
        node.removeAttribute @removeNotEndWith
        # 含まれていない場合にtrue
        res = a.lastIndexOf(b)
        (res < 0 or (a.length - b.length) isnt a.lastIndexOf(b))

      node.parentNode.removeChild node if res and node.parentNode?

    existId = {}
    for node in @idNodes
      existId[node.getAttribute(@id)] |= node.parentNode?

    for node in @removeIfIdNodes
      id = node.getAttribute @removeIfId
      node.removeAttribute @removeIfId
    
      if node.getAttributeNode(@removeIdExist)
        res = existId[id]? and existId[id]
        node.removeAttribute @removeIdExist
      else if node.getAttributeNode(@removeIdNotExist)
        res = !existId[id]? or !existId[id]
        node.removeAttribute @removeIdNotExist

      node.parentNode.removeChild node if res and node.parentNode?

    # removeの削除
    for node in @removeNodes
      node.parentNode.removeChild node if node.parentNode?

    @init_track()

  template: (doc, data, previous_vars)->
    vars   = {}
    blocks = {}

    ##
    # DOMを走査
    stack = []
    stack.push
      node:    doc
      i:       0

    while stack[0]?
      jobAdded = false # 多重ループを抜けるためのフラグ
      job = stack.pop()
      while job.node.childNodes[job.i]?
        child = job.node.childNodes[job.i]
        switch child.nodeType
          ##
          # text
          when 3
            if matches = child.nodeValue.match /\$\{[^}]+\}/g
              for match in matches 
                vars[match] = [] if !vars[match]?
                vars[match].push child
                @valueNodes.push child
              #@track_node job.node, 'var'

          ##
          # element
          # ここでclose時に必要になるフラグを全部付けてしまうか？
          when 1

            # close処理の為にnodeをtracking
            @track_node child, 'id'            if child.getAttributeNode(@id)?
            @track_node child, 'veil'          if child.getAttributeNode(@veil)?
            @track_node child, 'remove'        if child.getAttributeNode(@remove)?
            @track_node child, 'remove-if'     if child.getAttributeNode(@removeIf)?
            @track_node child, 'remove-if-id'  if child.getAttributeNode(@removeIfId)?
            @track_node child, 'insert_before' if child.getAttributeNode(@insertBefore)?
            @track_node child, 'append'        if child.getAttributeNode(@append)?
            
            ##
            # blockであるか
            blockname = child.getAttribute 'data-tpl-block'
            if blockname? and '' != blockname.length
              blocks[blockname] = [] if !blocks[blockname]?
              blocks[blockname].push child
              @track_node child, 'block'
            else
              ##
              # 属性
              #hasVar = false
              for attr in child.attributes
                if matches = attr.nodeValue.match /\$\{[^}]+\}/g
                  for match in matches
                    vars[match] = [] if !vars[match]?
                    vars[match].push attr
                    @valueNodes.push attr
                  #hasVar = true
                  # tracking
                  #@track_node child, 'var' if hasVar

              ##
              # childNodesが0の時どういう扱いになるか
              # ブラウザによって異なるかもしれないから注意
              jobAdded = (1 <= child.childNodes.length) ? true : false
              if jobAdded
                job.i++
                stack.push job

                stack.push
                  node: child
                  i:    0
                break;
        #swich
        break if jobAdded
        job.i++

    ##
    # 自身の属性を追加
    for attr in doc.attributes
      if matches = attr.nodeValue.match /\$\{[^}]+\}/g
        for match in matches
          vars[match] = [] if !vars[match]?
          vars[match].push attr
          @valueNodes.push attr
    ##
    # 自身をトラッキング
    @track_node doc, 'id'            if doc.getAttributeNode(@id)?
    @track_node doc, 'veil'          if doc.getAttributeNode(@veil)?
    @track_node doc, 'remove'        if doc.getAttributeNode(@remove)?
    @track_node doc, 'remove-if'     if doc.getAttributeNode(@removeIf)?
    @track_node doc, 'remove-if-id'  if doc.getAttributeNode(@removeIfId)?
    @track_node doc, 'insert_before' if doc.getAttributeNode(@insertBefore)?
    @track_node doc, 'append'        if doc.getAttributeNode(@append)?

    ##
    # カレントスコープの変数、ブロックをセット
    data_vars   = {}
    data_blocks = {}
    for key, value of data
      switch Object.prototype.toString.call(value)
        when '[object Array]'
          # 配列
          data_blocks[key] = value
        when '[object Number]','[object String]','[object Boolean]','[object Null]','[object Undefined]'
          # プリミティブ
          data_vars[key] = value ? ""
        else
          # ハッシュ
          data_blocks[key] = [value]

    # 上ブロックの変数にアクセス
    newVars = {}
    i = 1 # @の数
    for parentVars in @varsStack.reverse()
      for key, value of parentVars
        for kipple in [0..i]
          key = "@#{key}"
        newVars[key] = value
      i += 1
    @varsStack.reverse()

    # カレントスコープの変数に直上スコープの変数をセット
    for parentVars in @varsStack
      for key, value of parentVars
        newVars[key] = value

    # @１つの変数はカレントスコープを明示する
    # ミックスイン
    for key, value of data_vars
      newVars[key] = value
      newVars["@#{key}"] = value

    # previousのミックスイン
    if previous_vars?
      for key, value of previous_vars
        newVars["##{key}"] = value

    ##
    # 変数の処理
    for varname, data of newVars
      varnames = [varname]
      varnames.push "#{@ns}:#{varname}" if @ns?

      for varname in varnames
        if nodes = vars["${#{varname}}"]
          varname = '\\$\\{' + varname + '\\}'                
          for node in nodes
            re = new RegExp varname, 'g'
            node.nodeValue = node.nodeValue.replace re, data
            @track_node node.ownerElement, 'var' if node.nodeType == 2
            @track_node node.parentNode, 'var' if node.nodeType == 3
        
    ##
    # ブロックの処理
    for blockname, datas of data_blocks
      if nodes = blocks[blockname]
        for node in nodes
          previous_vars = null
          for data, i in datas
            tpl = node.cloneNode true
            data_vars['_i'] = i
            @varsStack.push data_vars
            previous_vars = @template tpl, data, previous_vars
            @varsStack.pop()
            tpl.removeAttribute 'data-tpl-block'
            node.parentNode.insertBefore tpl, node
      
    return data_vars