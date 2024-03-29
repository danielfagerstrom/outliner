# Initialize app
useStorage = window.JSON and window.localStorage

class Outline
  constructor: ({@text, @children} = {}, @_parent) ->
    @text ?= ""
    @children = new List(@children, @)

class List
  constructor: ({@items, @_parent} = {}, @_parent) ->
    @items ?= []
    @items = (new Outline(item, @) for item in @items)
  remove: (index) ->
    @items[index]._parent = null
    $.observable(@items).remove index, 1
  insert: (item, index) ->
    index ?= @items.length
    item._parent = @
    $.observable(@items).insert index, item
  move: (from, to) ->
    $.observable(@items).move from, to
  demote: (index) ->
    if 0 < index < @items.length
      demotee = @items[index]
      @remove index
      @items[index - 1].children.insert demotee
  promote: (index) ->
    promotee = @items[index]
    parentList = @_parent?._parent
    if parentList
      indexInParentList = parentList.items.indexOf @_parent
      @remove index
      parentList.insert promotee, indexInParentList + 1

class OutlineDocument
  constructor: ->
    @list = new List({}, @)
  open: ->
    # Intialize from local storage
    items = useStorage and $.parseJSON(localStorage.getItem("JsViewsTodos")) or []
    console.log items
    @list = new List({items}, @)
  save: ->
    filterCircular = (key, value) -> if key in ["_parent"] then undefined else value
    console.log JSON.stringify(@list.items, filterCircular, 2)
    localStorage.setItem "JsViewsTodos", JSON.stringify(@list.items, filterCircular) if useStorage

doc = new OutlineDocument()
doc.open()

# Helper functions

# Provide afterChange handler for datalinking. (In this case it will be on the top view, so available to all views)
$.views.helpers onAfterChange: (ev) ->
  switch ev.type
    when "change"
      switch @path
        when "text"
          doc.save()
    when "arrayChange"
      doc.save()

# Compile template
$.templates
  itemTemplate: "#item-template"
  listTemplate: "#list-template"

# UI Event bindings
$("#new-outline").keypress (ev) ->
  if ev.keyCode is 13
    doc.list.insert new Outline(text: @value)
    @value = ""

# Link UI, and handle changes to 'text' property of items
$.link.listTemplate(
  "#outline-list",
  doc.list
).on("keydown", "div", (ev) ->
  view = $.view(this)
  switch ev.keyCode
    when 9 # tab
      if ev.shiftKey
        view.parent.parent.data.promote view.index
      else
        view.parent.parent.data.demote view.index
      ev.preventDefault()
    when 13 # enter
      view.parent.parent.data.insert new Outline(), view.index + 1
      newOutline = $(view.parent.views[view.index + 1].nodes, "div").contents()
      newOutline.focus()
      ev.preventDefault()
    when 38 # up arrow
      li = $(this).closest("li")
      if li.is("li:first-child")
        prevOrParent = li.parent().closest("li")
      else
        prevOrParent = li.prev("li").find("li").andSelf().last()
      prevOrParent.find("> div").focus()
      ev.preventDefault()
    when 40 # down arrow
      li = $(this).closest("li")
      firstLiChild = li.find("li")
      if firstLiChild.length
        childOrNext = firstLiChild.first()
      else
        childOrNext = li.parents("li").andSelf().next("li").last()
      childOrNext.find("> div").focus()
      ev.preventDefault()
).on("input", "div", (ev) ->
  view = $.view(this)
  $.observable(view.data).setProperty "text", $(this).text()
).on("click", ".outline-destroy", ->
  view = $.view(this)
  view.parent.parent.data.remove view.index
)

movedOutline = null
fromIndex = null
fromList = null

$(".outlines").sortable
  axis: "y"
  handle: ".handle"
  connectWith: ".outlines"
  start: (event, ui) ->
    fromView = $.view(ui.item)
    movedOutline = fromView.data
    fromIndex = fromView.index
    fromList = fromView.parent.parent.data
  update: (event, ui) ->
    parentNodes = ui.item.parent()
    if parentNodes.length
      toList = $.view(parentNodes).data
      fromView = $.view(ui.item)
      toIndex = $(ui.item).index()
      if fromList is toList
        fromList.move fromIndex, toIndex
      else
        if fromList.items[fromIndex] is movedOutline
          fromList.remove fromIndex
          toList.insert movedOutline, toIndex
        else
          console.error "trying to move twice"
  stop: (event, ui) ->
    movedOutline = null
    fromIndex = null
    fromList = null

# Connect change event to contentEditable
$('[contenteditable]')
  .live 'focus', ->
    $this = $(this)
    $this.data 'before', $this.html()
    return $this
  .live 'blur', -> # 'blur keyup paste'
    $this = $(this)
    if $this.data('before') isnt $this.html()
      $this.data 'before', $this.html()
      $this.trigger('change')
    return $this

# Hook into jsviews mechanism for linking from and to elements and override the default behaviour for
# div to be only readable (fromAttr == ""). It would be better to set the fromAttr for contentEditable
# elements, but there is no hook for that.
$.views.merge["div"] =
  from:
    fromAttr: "text"
  to:
    toAttr: "text"
