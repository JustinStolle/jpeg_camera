# Snapshot taken using {JpegCamera}.
class Snapshot
  # Snapshot IDs are unique within browser session. This class variable holds
  # the value of the next ID to use.
  #
  # @private
  @_next_snapshot_id: 1

  # @private
  constructor: (@camera, @options) ->
    @id = @constructor._next_snapshot_id++

  _discarded: false

  # Display the snapshot with the camera element it was taken with.
  #
  # @return [Snapshot] Self for chaining.
  show: ->
    raise "discarded snapshot cannot be used" if @_discarded

    @camera._display @
    @

  # Stop displaying the snapshot and return to showing live camera stream.
  #
  # Ignored if camera is displaying different snapshot.
  #
  # @return [Snapshot] Self for chaining.
  hide: ->
    if @camera.displayed_snapshot() == @
      @camera.show_stream()
    @

  # Upload the snapshot to the server.
  #
  # The snapshot is uploaded using a POST request with JPEG file sent as RAW
  # data. This not like a multipart form upload using file element where the
  # file is given a name and is encoded along with other form keys. To read
  # file contents on the server side use `request.raw_post` in Ruby on Rails or
  # `$HTTP_RAW_POST_DATA` in PHP.
  #
  # Upload completes successfully only if the server responds with status code
  # 200. Any other code will be handled via on_upload_fail callback. Your
  # application is free to inspect the status code and response text in that
  # handler to decide whether that response is acceptable or not.
  #
  # You cannot have multiple uploads for one snapshot running at the same time,
  # but you are free to start another upload after one succeeds or fails.
  #
  # All of the options can have their defaults set when constructing camera
  # object or calling {JpegCamera#capture}.
  #
  # @option options api_url [String] URL where the snapshots will be uploaded.
  # @option options csrf_token [String] CSRF token to be sent in the
  #   __X-CSRF-Token__ header during upload.
  # @option options timeout [Integer] __IGNORED__ (__NOT__ __IMPLEMENTED__)
  #   The number of milliseconds a request can take before automatically being
  #   terminated. Default of 0 means there is no timeout.
  # @option options on_upload_done [Function] Function to call when upload
  #   completes. Snapshot object will be available as _this_, response body will
  #   be passed as the first argument. Calling {Snapshot#done done} before the
  #   upload exits will change the handler for this upload.
  # @option options on_upload_fail [Function] Function to call when upload
  #   fails. Snapshot object will be available as _this_, response code will
  #   be passed as the first argument followed by error message and response
  #   body. Calling {Snapshot#fail fail} before the upload exits will change
  #   the handler for this upload.
  #
  # @return [Snapshot] Self for chaining.
  upload: (options = {}) ->
    raise "discarded snapshot cannot be used" if @_discarded

    if @_uploading
      @_debug "Upload already in progress"
      return
    @_uploading = true

    @_upload_options = options
    cache = @_options()

    unless cache.api_url
      @camera._debug "Snapshot#upload called without valid api_url"
      throw "Snapshot#upload called without valid api_url"

    if "string" == typeof cache.csrf_token && cache.csrf_token.length > 0
      csrf_token = cache.csrf_token
    else
      csrf_token = null

    @_done = false
    @_response = null
    @_fail = false
    @_status = null
    @_error_message = null

    @camera._upload @, cache.api_url, csrf_token, cache.timeout
    @

  _upload_options: {}
  _uploading: false

  # Bind callback for upload complete event.
  #
  # The callback to fire when the previously requested {Snapshot#upload upload}
  # operation succeeds. This is just a syntactic sugar that allows one to write:
  # `snapshot.upload().done(done_callback)` instead of
  # `snapshot.upload(on_upload_done: done_callback)`. This callback will be
  # forgotten after the next call to {Snapshot#upload upload}.
  #
  # If the event has already happened the argument will be called immediately.
  #
  # @param callback [Function] function to call when upload completes. Snapshot
  #   object will be available as _this_, response body will be passed as the
  #   first argument.
  #
  # @return [Snapshot] Self for chaining.
  done: (callback) ->
    raise "discarded snapshot cannot be used" if @_discarded

    @_upload_options.on_upload_done = callback
    cache = @_options()
    if cache.on_upload_done && @_done
      cache.on_upload_done.call @, @_response
    @

  _done: false
  _response: null

  # Bind callback for upload error event.
  #
  #
  # The callback to fire when the previously requested {Snapshot#upload upload}
  # operation fails. This is just a syntactic sugar that allows one to write:
  # `snapshot.upload().fail(fail_callback)` instead of
  # `snapshot.upload(on_upload_fail: fail_callback)`. This callback will be
  # forgotten after the next call to {Snapshot#upload upload}.
  #
  # If the event has already happened the argument will be called immediately.
  #
  # @param callback [Function] function to call when upload fails. Snapshot
  #   object will be available as _this_, response code will be passed as the
  #   first argument with response body or error message as the second argument
  #   if available.
  #
  # @return [Snapshot] Self for chaining.
  fail: (callback) ->
    raise "discarded snapshot cannot be used" if @_discarded

    @_upload_options.on_upload_fail = callback
    cache = @_options()
    if cache.on_upload_fail && @_fail
      cache.on_upload_fail.call @, @_status, @_error_message, @_response
    @

  _fail: false
  _status: null
  _error_message: null

  # Hide and discard this snapshot.
  #
  # After discarding a snapshot an attempt to show or upload it will raise
  # an error.
  #
  # @return [void]
  discard: ->
    @camera._discard @
    undefined

  # Snapshot options
  #
  # @private
  _options: ->
    @camera._extend {}, @camera.options, @options, @_upload_options

  # Called by the camera engine when upload completes.
  #
  # @private
  _upload_done: ->
    @camera._debug "Upload completed"
    @_uploading = false
    @_done = true
    cache = @_options()
    if cache.on_upload_done
      cache.on_upload_done.call @, @_response

  # Called by the camera engine when upload fails.
  #
  # @private
  _upload_fail: ->
    @camera._debug "Upload failed with status #{@_status}"
    @_uploading = false
    @_fail = true
    cache = @_options()
    if cache.on_upload_fail
      cache.on_upload_fail.call @, @_status, @_error_message, @_response