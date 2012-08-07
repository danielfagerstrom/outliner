# Initialize app
useStorage = window.JSON and window.localStorage

class Outline
  constructor: (@text = "") ->

class List
  constructor: ->
    # Intialize from local storage
    @items = useStorage and $.parseJSON(localStorage.getItem("JsViewsTodos")) or []
  remove: (index, item) ->
    $.observable(@items).remove index, 1
  insert: (index, item) ->
    $.observable(@items).insert index, item
  move: (from, to) ->
    $.observable(@items).move from, to
  save: ->
    console.log JSON.stringify(@items)
    localStorage.setItem "JsViewsTodos", JSON.stringify(@items) if useStorage

list = new List()

# Helper functions

# Provide afterChange handler for datalinking. (In this case it will be on the top view, so available to all views)
$.views.helpers onAfterChange: (ev) ->
  switch ev.type
    when "change"
      view = $.view(@src)
      switch @path
        when "text"
          ;
    when "arrayChange"
      list.save()

# Compile template
$.templates
  itemTemplate: "#item-template"
  listTemplate: "#list-template"

# UI Event bindings
$("#new-outline").keypress (ev) ->
  if ev.keyCode is 13
    list.insert list.items.length, new Outline(@value)
    @value = ""

# Link UI, and handle changes to 'text' property of items
$.link.listTemplate("#outline-list", list
).on("keypress", "div", (ev) ->
  view = $.view(this)
  if ev.keyCode is 13
    list.insert view.index + 1, new Outline()
    newOutline = $(view.parent.views[view.index + 1].nodes, "div").contents()
    newOutline.focus()
    ev.preventDefault()
).on("keydown", "div", (ev) ->
  view = $.view(this)
  if ev.keyCode is 38
    prevOutline = $(view.parent.views[view.index - 1].nodes, "div").contents()
    prevOutline.focus()
    ev.preventDefault()
  else if ev.keyCode is 40
    nextOutline = $(view.parent.views[view.index + 1].nodes, "div").contents()
    nextOutline.focus()
    ev.preventDefault()
).on("input", "div", (ev) ->
  view = $.view(this)
  $.observable(view.data).setProperty "text", $(this).text()
).on("click", ".outline-destroy", ->
  view = $.view(this)
  list.remove view.index, view.data
)

$(".outlines").sortable
  axis: "y"
  handle: ".handle"
  update: (event, ui) ->
    from = $.view(ui.item).index
    to = $(ui.item).index()
    console.log from, to
    list.move from, to
