"use strict"
# Pre dependencies
WindowController = require("controller/windowcontroller")

###*
@class TutorialController
  Controller for tutorial view (Controller, Singleton)
@extends WindowController
###
module.exports = class TutorialController extends WindowController
  null
  instance = null

  #--------------------------------------------------------------------------------
  # Public properties
  #

  ###*
  @static
  @property {TutorialController}
    The instance of this class
  @readonly
  ###
  @classProperty("instance", get: ->
    return instance or= new TutorialController(window)
  )

  #--------------------------------------------------------------------------------
  # Public methods
  #

  ###*
  @method constructor
    Constructor of MainController class
  @param {Window} window
    window object
  ###
  constructor: (window) ->
    super(window)
    return

  #--------------------------------------------------------------------------------
  # Protected methods
  #

  ###*
  @inheritdoc Controller#activate
  ###
  activate: ->
    return super(
    ).then(=>
      @$("body").addClass("controller-tutorial")
      return
    ) # return super().then()

  ###*
  @inheritdoc Controller#deactivate
  ###
  deactivate: ->
    @$("body").removeClass("controller-tutorial")
    return super()

# Post dependencies
I18n = require("util/i18n")
Preferences = require("app/preferences")
