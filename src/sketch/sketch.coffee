"use strict"
# Pre dependencies
JSONable = require("util/jsonable")
require("util/primitive")

###*
@class Sketch
  Sketch (Model)
@extends JSONable
###
module.exports = class Sketch extends JSONable
  Sketch.jsonable()

  #--------------------------------------------------------------------------------
  # Public properties
  #

  ###*
  @property {string} friendlyName
    Name of sketch (Same as directory name)
  @readonly
  ###
  @property("friendlyName", get: -> @_dirFs?.name)

  ###*
  @property {boolean} modified
    Is sketch modified
  @readonly
  ###
  @property("modified", get: -> @_modified)

  ###*
  @property {boolean} itemModified
    Is any sketch item modified
  @readonly
  ###
  @property("itemModified", get: ->
    return true for item in @items when item.editor?.modified
    return false
  )

  ###*
  @property {boolean} temporary
    Is sketch temporary
  @readonly
  ###
  @property("temporary", get: -> @_temporary)

  ###*
  @property {AsyncFs} dirFs
    File system object for sketch directory
  @readonly
  ###
  @property("dirFs", get: -> @_dirFs)

  ###*
  @property {SketchItem[]} items
    Array of items in sketch
  @readonly
  ###
  @property("items", get: -> Object.freeze(item for item in @_items))

  ###*
  @property {string} bootPath
    Path of boot item
  ###
  @property("bootPath",
    get: -> @bootItem?.path
    set: (v) -> @_modify =>
      if v?
        found = @_items.find((item) => item.path == v)
        throw Error("No item `#{v}'") unless found?
      @_bootPath = v
      return true
  )

  ###*
  @property {SketchItem} bootItem
    SketchItem instance of boot item
  @readonly
  ###
  @property("bootItem",
    get: ->
      bootPath = @_bootPath
      for item in @_items
        return item if item.path == bootPath
      return
  )

  ###*
  @property {Board} board
    Board instance
  ###
  @property("board",
    get: -> @_board
    set: (v) -> @_modify =>
      @_board = v
      @dispatchEvent({type: EVENT_SETBOARD})
      return true
  )

  ###*
  @property {Object} workspace
    Workspace information
  ###
  @property("workspace",
    get: -> @_workspace
    set: (v) -> @_workspace = v
  )

  ###*
  @static
  @property {number} STEP_START
    Constant number for step starting
  @readonly
  ###
  @classProperty("STEP_START", value: STEP_START = 0)

  ###*
  @static
  @property {number} STEP_PROGRESS
    Constant number for step in progress
  @readonly
  ###
  @classProperty("STEP_PROGRESS", value: STEP_PROGRESS = 1)

  ###*
  @static
  @property {number} STEP_FINISHED
    Constant number for step finished
  @readonly
  ###
  @classProperty("STEP_FINISHED", value: STEP_FINISHED = 2)

  ###*
  @static
  @property {number} STEP_SKIPPED
    Constant number for step skipped
  @readonly
  ###
  @classProperty("STEP_SKIPPED", value: STEP_SKIPPED = 3)

  ###*
  @static
  @property {number} STEP_ABORTED
    Constant number for step aborted
  @readonly
  ###
  @classProperty("STEP_ABORTED", value: STEP_ABORTED = 4)

  #--------------------------------------------------------------------------------
  # Events
  #

  ###*
  @event change.sketch
    Sketch changed (excludes each item's content change)
  @param {Object} event
    Event object
  @param {Sketch} event.target
    Sketch instance
  ###
  @event(EVENT_CHANGE = "change.sketch")

  ###*
  @event save.sketch
    Sketch saved
  @param {Object} event
    Event object
  @param {Sketch} event.target
    Sketch instance
  ###
  @event(EVENT_SAVE = "save.sketch")

  ###*
  @event setboard.sketch
    Board set
  @param {Object} event
    Event object
  @param {Sketch} event.target
    Sketch instance
  ###
  @event(EVENT_SETBOARD = "setboard.sketch")

  ###*
  @event additem.sketch
    SketchItem added
  @param {Object} event
    Event object
  @param {Sketch} event.target
    Sketch instance
  @param {SketchItem} event.item
    Added item
  ###
  @event(EVENT_ADDITEM = "additem.sketch")

  ###*
  @event removeitem.sketch
    SketchItem being removed
  @param {Object} event
    Event object
  @param {Sketch} event.target
    Sketch instance
  @param {SketchItem} event.item
    Item removed
  ###
  @event(EVENT_REMOVEITEM = "removeitem.sketch")

  #--------------------------------------------------------------------------------
  # Private constants
  #

  SKETCH_CONFIG   = "sketch.json"
  SKETCH_ENCODING = "utf8"
  arrayEqual = (a1, a2) ->
    return true if a1 == a2
    return false unless a1? and a2?
    return false if a1.length != a2.length
    (return false if v != a2[i]) for v, i in a1
    return true

  #--------------------------------------------------------------------------------
  # Public methods
  #

  ###*
  @static
  @method
    Create empty sketch on temporary storage
  @param {string} [name]
    Name of new sketch
  @return {Promise}
    Promise object
  @return {Sketch} return.PromiseValue
    The instance of sketch
  ###
  @createNew: (name) ->
    name or= strftime("sketch_%Y%m%d_%H%M%S")
    sketch = null
    return AsyncFs.opentmpfs().then((fs) =>
      return fs.opendirfs(name).catch(=>
        return fs.mkdir(name).then(=>
          return fs.opendirfs(name)
        )
      )
    ).then((dirFs) =>
      sketch = new Sketch()
      return sketch.save(dirFs)
    ).then(=>
      sketch._temporary = true
      return sketch
    ) # return AsyncFs.opentmpfs().then()...

  ###*
  @static
  @method
    Open a sketch
  @param {AsyncFs} dirFs
    File system object at the sketch directory
  @return {Promise}
    Promise object
  @return {Object} return.PromiseValue
  @return {Sketch} return.PromiseValue.sketch
    The instance of sketch
  @return {Object} return.PromiseValue.migration
    Migration info (from,to,regenerate,catalogUpdate)
  ###
  @open: (dirFs) ->
    migration = null
    return dirFs.readFile(SKETCH_CONFIG, SKETCH_ENCODING).then((data) =>
      obj = @_migrateAtOpen(JSON.parse(data))
      migration = obj.__migration__
      return Sketch.parseJSON(obj)
    ).then((sketch) =>
      sketch._dirFs = dirFs
      return {sketch: sketch, migration: migration}
    ).catch(=>
      return I18n.rejectPromise("Invalid_sketch")
    ) # return dirFs.readFile().then()...

  ###*
  @static
  @method
    Check if sketch exists
  @param {AsyncFs} dirFs
    File system object at the sketch directory
  @return {Promise}
    Promise object
  @return {boolean} return.PromiseValue
    True if sketch already exists
  ###
  @exists: (dirFs) ->
    return dirFs.readFile(SKETCH_CONFIG, SKETCH_ENCODING).then(=>
      return true
    ).catch(=>
      return false
    )

  ###*
  @method
    Save sketch
  @param {AsyncFs} [newDirFs]
    File system object to store sketch
  @return {Promise}
    Promise object
  ###
  save: (newDirFs) ->
    if newDirFs?
      # Update properties
      oldDirFs = @_dirFs
      @_dirFs = newDirFs
    return @_items.reduce(
      # Save all files in sketch
      (promise, item) =>
        if item.editor?
          return promise unless newDirFs? or item.editor.modified
          return promise.then(=> item.editor.save())
        return promise unless newDirFs?
        # Relocate file
        return promise.then(=>
          return oldDirFs.readFile(item.path)
        ).catch((error) =>
          return  # No file
        ).then((data) =>
          return unless data?
          return newDirFs.writeFile(item.path, data)
        )
      Promise.resolve()
    ).then(=>
      # Save sketch settings
      @_rubicVersion = App.version
      return @_dirFs.writeFile(SKETCH_CONFIG, JSON.stringify(this), SKETCH_ENCODING)
    ).then(=>
      # Successfully saved
      @_modified = false
      newDirFs = null
      @dispatchEvent({type: EVENT_SAVE})
      return  # Last PromiseValue
    ).finally(=>
      # Revert properties if failed
      @_dirFs = oldDirFs if newDirFs?
      return
    ) # return @_items.reduce().then()...

  ###*
  @method
    Generate skeleton code
  @return {Promise}
    Promise object
  ###
  generateSkeleton: ->
    return Promise.reject(Error("No board")) unless @_board?
    return Promise.resolve(
    ).then(=>
      # Execute setup to unbind non-supported builders
      return @setupItems()
    ).then(=>
      return @_board.loadFirmRevision()
    ).then((firmRevision) =>
      item = @bootItem
      return if item?.builder?
      builderClass = null
      template = null
      for cls in firmRevision.builderClasses
        template = cls.template
        if template.suffix?
          builderClass = cls
          break
      return Promise.reject(Error("No builder class")) unless builderClass?
      mainPrefix = "main."
      mainPath = "#{mainPrefix}#{template.suffix}"
      return Promise.resolve(
      ).then(=>
        return if @hasItem(mainPath)

        # Create new boot item
        item = @getItem(mainPath, true)
        return item.writeContent(
          template.content?.toString() or ""
          {encoding: "utf8"}
        ).then(=>
          # Execute setup again to bind builder to new item
          return @setupItems()
        )
      ).then(=>
        exes = firmRevision.executables
        exe = null
        for item in @_items
          (exe = item) for e in exes when e.test(item.path)
          break if exe?.path.startsWith(mainPrefix)
        @bootPath = exe?.path
      ) # return Promise.resolve().then()...
    ).then(=>
      return  # Last PromiseValue
    ) # return Promise.resolve().then()...

  ###*
  @method
    Check if item in sketch
  @param {SketchItem/string} item
    Item or path
  @return {boolean}
    true if exists
  ###
  hasItem: (item) ->
    if typeof(item) == "string"
      comparator = (i) => i.path == item
    else
      comparator = (i) => i == item
    return (@_items.findIndex(comparator) >= 0)

  ###*
  @method
    Get item in sketch
  @param {string} path
    Path of item
  @param {boolean} create
    Create if not exists
  @return {SketchItem/null}
    Item
  ###
  getItem: (path, create = false) ->
    return item for item in @_items when item.path == path
    if create
      item = new SketchItem({path: path}, this)
      return item if @addItem(item)
    return null

  ###*
  @method
    Add item to sketch
  @param {SketchItem} item
    Item to add
  @param {boolean} [suppressEvents=false]
    Suppress events
  @return {boolean}
    Result (true=success, false=already_exists)
  ###
  addItem: (item, suppressEvents = false) ->
    return false if @hasItem(item.path)
    return false if item.path == SKETCH_CONFIG
    item.setSketch(this)
    item.addEventListener("change.sketchitem", this)
    @_items.push(item)
    unless suppressEvents
      @_modify(=> true)
      @dispatchEvent({type: EVENT_ADDITEM, item: item})
    return true

  ###*
  @method
    Remove item from sketch
  @param {SketchItem/string} item
    Item or path to remove
  @return {boolean}
    Result (true=success, false=not_found)
  ###
  removeItem: (item) ->
    path = item
    path = item.path unless typeof(item) == "string"
    index = @_items.findIndex((value) => value.path == path)
    return false if index < 0
    itemRemoved = @_items[index]
    itemRemoved.removeEventListener("change.sketchitem", this)
    @_items.splice(index, 1)
    @_modify(=> true)
    @dispatchEvent({type: EVENT_REMOVEITEM, item: itemRemoved})
    return true

  ###*
  @method
    Setup items
  @return {Promise}
    Promise object
  ###
  setupItems: ->
    return Promise.resolve(
    ).then(=>
      return @_board?.loadFirmRevision()
    ).then((firmRevision) =>
      return unless firmRevision?
      builderClasses = firmRevision.builderClasses
      return @_items.reduce(
        (promise, item) =>
          if item.builder?
            for cls in builderClasses
              return promise.then(=>
                return item.builder.setup()
              ) if item.builder instanceof cls
            # Remove unsuported builder
            item.builder = null
          for cls in builderClasses
            continue unless cls.supports(item.path)
            # Add builder
            return promise.then(=>
              return new cls({}, item).setup()
            )
          return promise
        Promise.resolve()
      ) # return @_items.reduce()
    ) # return Promise.resolve().then()...

  ###*
  @method
    Build sketch
  @param {boolean} [force=false]
    Force build all files
  @param {function(string,number,number,Error)} [progress=null]
    Hook function for show progress
  @return {Promise}
    Promise object
  ###
  build: (force = false, progress = null) ->
    @_lastBuilt or= -1

    # Resolve dependencies
    candidates = (item for item in @_items when item.builder?)
    buildItems = []
    while candidates.length > 0
      found = false
      index = 0
      while index < candidates.length
        item = candidates[index]
        src = item.source
        if !src? or buildItems.includes(src)
          buildItems.push(item)
          candidates.splice(index, 1)
          found = true
        else
          ++index
      unless found
        return I18n.rejectPromise("Cannot_resolve_build_order")
    App.log("Resolved build dependency: %o", buildItems)

    # Build
    done = 0
    return buildItems.reduce(
      (promise, item) =>
        if !force and ((item.source?.lastModified or item.lastModified) < @_lastBuilt)
          return promise  # Skip
        return promise.then(=>
          engine = item.engine
          progress?(item.path, (100 * done / buildItems.length), STEP_START)
          return item.builder.build().catch((error) =>
            progress?(item.path, null, STEP_ABORTED, error)
            return Promise.reject(error)
          )
        ).then(=>
          progress?(item.path, (100 * ++done / buildItems.length), STEP_FINISHED)
          return
        ).delay(1).then(=>
          @_lastBuilt = Date.now()
        )
      Promise.resolve()
    ) # return buildItems.reduce()

  ###*
  @method
    Transfer sketch (Rubic->Board)
  @param {boolean} [force=false]
    Force download all files
  @param {function(string,number,number,Error)} [progress=null]
    Hook function for show progress
  @return {Promise}
    Promise object
  ###
  transfer: (force = false, progress = null) ->
    return Promise.reject(Error("No board")) unless @_board?
    transferItems = (item for item in @_items when item.transfer)
    boardFs = null
    done = 0
    return transferItems.reduce(
      (promise, item) =>
        written = false
        return promise.then(=>
          progress?(item.path, (100 * done / transferItems.length), STEP_START)
          return @_dirFs.readFile(item.path).catch((error) =>
            progress?(item.path, null, error)
            return Promise.reject(error)
          )
        ).then((content) =>
          return Promise.resolve(
          ).then(=>
            return if force
            tModify = item.lastModified
            tTrans  = item.lastTransfered
            tConn   = @_board.lastConnected
            return if (tModify < tTrans) and (tConn < tTrans)
            return boardFs.readFile(item.path).catch(=>
              return  # Ignore errors on readFile()
            )
          ).then((compare) =>
            if !force and compare?
              return if arrayEqual(new Uint8Array(content), new Uint8Array(compare))
            written = true
            return boardFs.writeFile(item.path, content).then(=>
              item.setTransfered()
            ).catch((error) =>
              progress?(item.path, null, STEP_ABORTED, error)
              return Promise.reject(error)
            )
          )
        ).then(=>
          progress?(
            item.path
            (100 * ++done / transferItems.length)
            if written then STEP_FINISHED else STEP_SKIPPED
          )
          return
        )
      @_board.requestFileSystem("internal").then((fs) =>
        boardFs = fs
        return
      )
    ) # return transferItems.reduce()

  #--------------------------------------------------------------------------------
  # Protected methods
  #

  ###*
  @protected
  @method constructor
    Constructor of Sketch class
  @param {Object} obj
    JSON object
  ###
  constructor: (obj = {}) ->
    super(obj)
    @_rubicVersion = obj.rubicVersion?.toString()
    @_items = []
    @addItem(SketchItem.parseJSON(item), true) for item in (obj?.items or [])
    @_bootPath = obj.bootPath?.toString()
    @_board = Board.parseJSON(obj.board) if obj.board?
    @_workspace = obj.workspace
    @_modified = false
    return

  ###*
  @protected
  @inheritdoc JSONable#toJSON
  ###
  toJSON: ->
    return super().extends({
      rubicVersion: @_rubicVersion
      items: (item.toJSON() for item in @_items)
      bootPath: @_bootPath
      board: @_board?.toJSON()
      workspace: @_workspace
    })

  ###*
  @protected
  @method
    Event handler
  @param {Object} event
    Event object
  @return {undefined}
  ###
  handleEvent: (event) ->
    switch event.type
      when "change.sketchitem"
        @dispatchEvent({type: EVENT_CHANGE})
    return

  #--------------------------------------------------------------------------------
  # Private methods
  #

  ###*
  @private
  @method
    Notify modifications
  @param {Function} callback
    Callback function
  @return {undefined}
  ###
  _modify: (callback) ->
    return unless callback.call(this)?
    @_modified = true
    @dispatchEvent({type: EVENT_CHANGE})
    return

  ###*
  @private
  @method
    Execute version migration
  @param {Object} src
    Source JSON object
  @return {Object}
    Migrated JSON object
  ###
  @_migrateAtOpen: (src) ->
    switch src.rubicVersion
      when undefined
        # Migration from 0.2.x
        result = {
          __class__: "Sketch"
          rubicVersion: src.sketch.rubicVersion
          items: [
            new SketchItem({
              path: "main.rb"
              builder: new MrubyBuilder({}, null).toJSON()
              transfer: false
            }).toJSON()
          ]
          workspace: {
            editors: [
              {className: "SketchEditor"}
              {className: "RubyEditor", path: "main.rb", active: true}
            ]
          }
          __migration__: {
            from: src.__migration__?.from or "0.2.x"
            to: "0.9.0"
            regenerate: true
            catalogUpdate: true
          }
        }
        switch src.sketch.board.class
          when "PeridotBoard"
            result.board = new PeridotBoard({
              firmwareId:     "d0a9b0f1-ff57-4f3b-b121-d8e5ad173725"
              firmRevisionId: "56624804-fc8d-4388-8560-5e5eec08067d"
            }).toJSON()
          when "WakayamaRbBoard"
            result.board = new WakayamaRbBoard({
              firmwareId:     "1ac3a112-1640-482f-8ca3-cf5afc181fe6"
              firmRevisionId: "6a253d8b-bf94-4bff-a3e6-9a5d8b60bdb3"
            }).toJSON()
          when "GrCitrusBoard"
            result.board = new GrCitrusBoard({
              firmwareId:     "809d1206-8cd8-46f6-a657-2f60c050d7c9"
              firmRevisionId: "bf956a8a-0f0d-41c2-8943-d46067162c79"
            }).toJSON()
        return result
      else
        # No migration needed from >= 0.9.x
        return src

# Post dependencies
strftime = require("util/strftime")
I18n = require("util/i18n")
AsyncFs = require("filesystem/asyncfs")
App = require("app/app")
Board = require("board/board")
SketchItem = require("sketch/sketchitem")
MrubyBuilder = require("builder/mrubybuilder")
PeridotBoard = require("board/peridotboard")
WakayamaRbBoard = require("board/wakayamarbboard")
GrCitrusBoard = require("board/grcitrusboard")
