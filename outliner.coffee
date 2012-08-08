# Initialize app
useStorage = window.JSON and window.localStorage

class Outline
  constructor: ({@text, @children} = {}) ->
    @text ?= ""
    @children = new List(@children)

class List
  constructor: ({@items} = {}) ->
    # Intialize from local storage
    @items ?= []
    @items = (new Outline(item) for item in @items)
  remove: (index) ->
    $.observable(@items).remove index, 1
  insert: (item, index) ->
    index ?= @items.length
    $.observable(@items).insert index, item
  move: (from, to) ->
    $.observable(@items).move from, to
  demote: (index) ->
    if 0 < index < @items.length
      demotee = @items[index]
      @remove index
      @items[index - 1].children.insert demotee
  open: ->
    # Intialize from local storage
    @items = useStorage and $.parseJSON(localStorage.getItem("JsViewsTodos")) or []
    console.log @items
    @items = (new Outline(item) for item in @items)
    console.log JSON.stringify(@items, null, 2)
  save: ->
    console.log JSON.stringify(@items, null, 2)
    localStorage.setItem "JsViewsTodos", JSON.stringify(@items) if useStorage

list = new List()
list.open()

# Helper functions

# Provide afterChange handler for datalinking. (In this case it will be on the top view, so available to all views)
$.views.helpers onAfterChange: (ev) ->
  switch ev.type
    when "change"
      switch @path
        when "text"
          list.save()
    when "arrayChange"
      list.save()

# Compile template
$.templates
  itemTemplate: "#item-template"
  listTemplate: "#list-template"

# UI Event bindings
$("#new-outline").keypress (ev) ->
  if ev.keyCode is 13
    list.insert new Outline(text: @value)
    @value = ""

# Link UI, and handle changes to 'text' property of items
$.link.listTemplate(
  "#outline-list",
  list
).on("keydown", "div", (ev) ->
  view = $.view(this)
  switch ev.keyCode
    when 9 # tab
      if ev.shiftKey
        console.log "shift+tab"
      else
        view.parent.parent.data.demote view.index
        ev.preventDefault()
    when 13 # enter
      view.parent.parent.data.insert new Outline(), view.index + 1
      newOutline = $(view.parent.views[view.index + 1].nodes, "div").contents()
      newOutline.focus()
      ev.preventDefault()
    when 38 # up arrow
      prevOutline = $(view.parent.views[view.index - 1].nodes, "div").contents()
      prevOutline.focus()
      ev.preventDefault()
    when 40 # down arrow
      nextOutline = $(view.parent.views[view.index + 1].nodes, "div").contents()
      nextOutline.focus()
      ev.preventDefault()
).on("input", "div", (ev) ->
  view = $.view(this)
  $.observable(view.data).setProperty "text", $(this).text()
).on("click", ".outline-destroy", ->
  view = $.view(this)
  view.parent.parent.data.remove view.index
)

$(".outlines").sortable
  axis: "y"
  handle: ".handle"
  update: (event, ui) ->
    fromView = $.view(ui.item)
    from = fromView.index
    to = $(ui.item).index()
    fromView.parent.parent.data.move from, to

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
