###*
Application main class
###
class App
  ###*
  @property {String}
  @nullable
  Last error message
  ###
  @lastError: null

  ###*
  @property {Sketch}
  @nullable
  Current sketch
  ###
  @sketch: null

  ###*
  @property {String}
  Default suffix (language) for new sketches including "." character
  ###
  @defaultSuffix: ".rb"

  ###*
  @method
  Show modal spin
  ###
  @showModalSpin: ->
    # console.log("ModalSpin.show(#{@count} -> #{@count+1})")
    @_spin.modal({
      show: true
      backdrop: "static"
      keyboard: false
    }) if @_spinCount == 0
    @_spinCount += 1

  ###*
  @method
  Hide modal spin
  ###
  @hideModalSpin: ->
    # console.log("ModalSpin.hide(#{@count} -> #{@count-1})")
    @_spinCount -= 1
    @_spin.modal('hide') if @_spinCount == 0

  ###*
  @private
  Spin object
  ###
  @_spin: null
  $(=>
    @_spin = $("#modal-spin").spin({color: "#fff"})
  )

  ###*
  @private
  Spin nest level
  ###
  @_spinCount: 0

  ###*
  @method
  Generate notify message for error
  ###
  @error: -> @notify(arguments, "danger")

  ###*
  @method
  Generate notify message for warning
  ###
  @warning: -> @notify(arguments, "warning")

  ###*
  @method
  Generate notify message for general information
  ###
  @info: -> @notify(arguments, "info")

  ###*
  Generate notify message for success
  ###
  @success: -> @notify(arguments, "success")

  ###*
  @method
  Generate notify message for debugging
  ###
  @debug: -> console.log(arguments)

  ###*
  @method
  Generate popup notify message
  ###
  @notify: ([message, options], type) ->
    $.notify(message, $.extend({
      type: type
      allow_dismiss: true
      placement: {from: "bottom", align: "center"}
      delay: 2000
      newest_on_top: true
      offset: 52
    }, options))

  ###*
  @method
  Add a new key bind
  @param {String}   key       Key combination by "Ctrl+A" like format
  @param {String}   desc      Description of action
  @param {Function} callback  Function called when key pressed
  ###
  @bindKey: (key, desc, callback) ->
    # Get modifier
    mod = [(-> not @altKey), (-> not @ctrlKey), (-> not @shiftKey)]
    key = key.replace('Alt+', -> (mod[0] = (-> @altKey); ''))
    key = key.replace('Ctrl+', -> (mod[1] = (-> @ctrlKey); ''))
    key = key.replace('Shift+', -> (mod[2] = (-> @shiftKey); ''))

    # Get key code
    if key.match(/^[A-Z0-9]$/)
      code = key.charCodeAt(0)
    else
      match = key.match(/^F(\d+)$/)
      if match
        code = parseInt(match[1]) + 0x6f
    if not code
      throw new Error("Unknown key name")

    # Bind to document
    $(document).keydown((event) =>
      return unless event.keyCode == code
      for m in mod
        return unless m.call(event)
      callback(event)
      event.preventDefault()
    )
    #  @_list.push({key: key, desc: desc})

$("#menu").click(->
  Editor.focus()
  $("#wrapper").toggleClass("toggled")
)