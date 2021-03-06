debug = require("debug")("winston-blob-transport")

_ = require "lodash"
util = require "util"
errorToJson = require "error-to-json"
azure = require "azure-storage"
async = require "async"
winston = require "winston"
chunk = require "chunk"
Promise = require "bluebird"

Transport = winston.Transport

MAX_BLOCK_SIZE = azure.Constants.BlobConstants.MAX_BLOCK_SIZE

MB = azure.Constants.MB;

HOUR_IN_MILLISECONDS = 60000 * 5;

class BlobTransport extends Transport

  constructor: ({@account, @containerName, @blobName, @maxBlobSize, @maxBlockCount = 48000 , @level = "info"}) ->
    @maxBlobSize = if @maxBlobSize then (@maxBlobSize * MB) else undefined
    @origBlobName = @blobName
    @blobName = if @maxBlobSize then (@blobName + '-' + @_timestamp() + ".log") else @origBlobName
    @name = "BlobTransport"
    @cargo = @_buildCargo()
    @client = @_buildClient @account
    @createNewBlobIfMaxSize();

  rollBlob: ()=>
    instance = this;
    instance.blobName = instance.origBlobName + '-' + instance._timestamp() + ".log";

  createNewBlobIfMaxSize: () =>
    instance = this;
    setInterval ->
       instance.client.listBlobsSegmentedWithPrefix(instance.containerName, instance.blobName, null,(err, result, response)->
        if (err?)
          # Not much we can do here; swallow the error. Usually the next check will pass.
        else if result && result.entries[0] && result.entries[0].contentLength >= instance.maxBlobSize
           instance.rollBlob();
       )
    ,HOUR_IN_MILLISECONDS

  initialize: ->
     Promise.promisifyAll azure.createBlobService @account.name, @account.key
      .createContainerIfNotExistsAsync @containerName, publicAccessLevel: "blob"
      .then (created) => debug "Container: #{@container} - #{if created then 'creada' else 'existente'}"

  log: (level, msg, meta, callback) =>
    line = @_formatLine {level, msg, meta}
    @cargo.push { line, callback }
    return

  _buildCargo: =>
    instance = this;
    async.cargo (tasks, __whenFinishCargo) =>
      __whenLogAllBlock = ->
        debug "Finish append all lines to blob"
        _.each tasks, ({callback}) -> callback null, true
        __whenFinishCargo()

      debug "Log #{tasks.length}th lines"
      logBlock = _.map(tasks, "line").join ""

      debug "Starting append log lines to blob. Size #{logBlock.length}"
      chunks = chunk logBlock, MAX_BLOCK_SIZE
      debug "Saving #{chunks.length} chunk(s)"

      async.eachSeries chunks, (chunk, whenLoggedChunk) =>
        debug "Saving log with size #{chunk.length}"
        @client.appendFromText @containerName, @blobName, chunk, (err, result) =>
          return @_retryIfNecessary(err, chunk, whenLoggedChunk) if err
          instance.rollBlob() if result.committedBlockCount >= instance.maxBlockCount
          whenLoggedChunk()
      , (err) ->
        debug "Error in block" if err
        __whenLogAllBlock()

  _retryIfNecessary: (err, block, whenLoggedChunk) =>
    __createAndAppend = => @client.createAppendBlobFromText @containerName, @blobName, block, {}, __handle
    __doesNotExistFile = -> err.code? && err.code is "NotFound"
    __handle = (err) ->
      debug "Error in append", err if err
      whenLoggedChunk()

    if __doesNotExistFile() then __createAndAppend() else __handle err

  _formatLine: ({level, msg, meta}) => "[#{level}] - #{@_timestamp()} - #{msg} #{@_meta(meta)} \n"

  _timestamp: -> new Date().toISOString()

  _meta: (meta) =>
    meta = errorToJson meta if meta instanceof Error
    if _.isEmpty meta then "" else "- #{util.inspect(meta)}"

  _buildClient : ({name, key}) =>
    azure.createBlobService name, key

#
# Define a getter so that `winston.transports.AzureBlob`
# is available and thus backwards compatible.
#
winston.transports.AzureBlob = BlobTransport

module.exports = BlobTransport
