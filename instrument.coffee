_ = require 'underscore'
talib = require('./talib_sync')

class Instrument
  constructor: (@platform,@id,@data_length)->
    @open = []
    @low = []
    @high = []
    @close = []
    @volumes = []
    @ticks = []
    @pair = @id.split('_')

  asset: ->
    @pair[0]

  curr: ->
    @pair[1]

  update: (data)->
    if @open.length == @data_length
      @open.shift()
      @low.shift()
      @high.shift()
      @close.shift()
      @volumes.shift()
      @ticks.shift()
    @open.push data.open
    @low.push data.low
    @high.push data.high
    @close.push data.close
    @volumes.push data.volume
    @price = data.close
    @volume = data.volume
    @ticks.push data

  vwap: (period)->
    if period < @ticks.length
      idx = @ticks.length - period
    else
      idx = 0
    flux = 0
    volume = 0
    while idx < @ticks.length
      flux += @volumes[idx] * @close[idx]
      volume += @volumes[idx]
      idx++
    if volume
      return flux / volume

  ema: (period)->
    output = talib.EMA
      name: 'EMA'
      startIdx: 0
      endIdx: @close.length-1
      inReal: @close
      optInTimePeriod: period
    _.last(output)

  macd: (fastPeriod, slowPeriod, signalPeriod)->
    results = talib.MACD
      name: 'MACD'
      startIdx: 0
      endIdx: @close.length-1
      inReal: @close
      optInFastPeriod: fastPeriod
      optInSlowPeriod: slowPeriod
      optInSignalPeriod: signalPeriod
    if results.outMACD.length
      output =
        macd: _.last results.outMACD
        signal: _.last results.outMACDSignal
        histogram: _.last results.outMACDHist
      output


module.exports = Instrument

