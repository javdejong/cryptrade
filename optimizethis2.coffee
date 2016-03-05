###
#
#EMA + MACD bot by sungkhum with johan's help
#reference: https://www.tradingview.com/v/vg9xeDcf/
#BTC Donations: 1PegF5ubz1pxun4qP8FhJ3br82BQRRFdoN
#
###
class GConfig
  @buy_threshold = [-1,5,parseFloat]
  @short = [1,60,parseInt]
  @long = [1,60,parseInt]
  @macd_1 = [1,60,parseInt]
  @macd_2 = [1,60,parseInt]
  @macd_3 = [1,60,parseInt]

init: (context)->
    context.diffs = [1000,1000,1000,1000]

handle: (context, data)->
  instrument = data.instruments[0]

  result = instrument.macd(GConfig.macd_1, GConfig.macd_2, GConfig.macd_3)
  short = instrument.ema(GConfig.short) # calculate EMA value using ta-lib function
  long = instrument.ema(GConfig.long) 
#  if result
#    info 'MACD Histogram='+result.histogram.toFixed(3)+' price: '+instrument.price.toFixed(2)
    #info 'MACD= '+result.macd.toFixed(3)+'  |  Signal= '+result.signal.toFixed(3)+' |  Histogram='+result.histogram.toFixed(3)

  plot
      macd: result.macd + 1000
      Signal: result.signal + 1000
      short: short
      long: long
      Histogram: result.histogram * 5 + 1000


  diff = 100 * (short - long) / ((short + long) / 2)
  uptrend = (diff < _.min(context.diffs))
#  info('diff: ' + diff + ' , max: ' + _.max(context.diffs) + ' thearray: ' + context.diffs)
  context.diffs.push(diff)
  context.diffs.shift()

#  info 'EMA difference: '+diff.toFixed(3)+' price: '+instrument.price.toFixed(2)
  if result.histogram < 0.0
      sell instrument # Sell asset position
  if diff > GConfig.buy_threshold
      buy instrument # Spend all amount of cash for asset
