class EMA
  constructor: (@period, is_alpha) ->
    # Also support directly setting the alpha. Clip to (0..1] to make
    # sure it makes sense and we avoid division by zero.
    if is_alpha? and is_alpha
      @period = Math.max(Number.MIN_VALUE, Math.min(@period, 1))
      @period = 2 / @period - 1

    @alpha = 2 / (@period + 1)

    if not @alpha? or isNaN(@alpha)
      throw "Alpha is undefined/NaN! Parameter passed in was: \"" + @period + "\""

  init: (values) ->
    @value = values[0]
    for newval in values[1..]
      @update(newval)
    @value

  update: (newval) ->
    @value = @value * (1 - @alpha) + newval * @alpha
    @value


class MACD
  constructor: (@period_short, @period_long, @period_signal, is_alpha) ->
    # Also support directly setting the alpha. Clip to (0..1] to make
    # sure it makes sense and we avoid division by zero.
    if is_alpha? and is_alpha
      @period_short  = 2 / Math.max(Number.MIN_VALUE, Math.min(@period_short, 1)) - 1
      @period_long   = 2 / Math.max(Number.MIN_VALUE, Math.min(@period_long, 1)) - 1
      @period_signal = 2 / Math.max(Number.MIN_VALUE, Math.min(@period_signal, 1)) -1

    # Short period should be smaller than long period
    if @period_long < @period_short
      temp = @period_long
      @period_long = @period_short
      @period_short = temp

    @ema_short  = new EMA(@period_short)
    @ema_long   = new EMA(@period_long)
    @ema_signal = new EMA(@period_signal)

  init: (values) ->
    @short = @ema_short.init([values[0]])
    @long = @ema_long.init([values[0]])
    @macd = @short - @long
    @signal = @ema_signal.init([@macd])

    for newval in values[1..]
      @update(newval)
    null

  update: (newval) ->
    last_sig_diff  = Math.sign(@macd - @signal)
    last_macd = @macd

    # Update
    @short  = @ema_short.update(newval)
    @long   = @ema_long.update(newval)
    @macd   = @short - @long
    @signal = @ema_signal.update(@macd)
    @histogram = @macd - @signal

    # Crossover detection:
    # Note that this might give two signals for a crossover (e.g. sign from -1
    # -> 0, and 0 -> 1)
    @signal_crossover = Math.sign(@macd - @signal) - last_sig_diff # Can be any value in [-2,-1,0,1,2]
    @signal_crossover = Math.sign(@signal_crossover) # normalize to [-1,0,1]
    @macd_crosszero   = Math.sign(Math.sign(@macd) - Math.sign(last_macd))
    null


class GConfig
  constructor: (nbars) ->
    @macd_long = [1, 100, parseInt]
    @macd_short = [0, 1, parseFloat]
    @macd_signal = [0, 1, parseFloat]

    @macd_sigcross_buy_thresh = [-50, 50, parseFloat]
    @macd_sigcross_sell_thresh = [-50, 50, parseFloat]


init: (context)->
  context.init_done = false


handle: (context, data)->
  instrument = data.instruments[0]

  data_length = instrument.open.length

  g = context.gconfig

  if not context.init_done
    # TODO: It should be possible to do this in init(), but for some reason
    # init() is called twice, and both with raw values instead of a properly
    # parsed GConfig
    long = g.macd_long
    short = parseInt(Math.max(long * g.macd_short, 1))
    signal = parseInt(Math.max(short * g.macd_signal, 1))
    context.macd = new MACD(short, long, signal)

    context.macd.init(instrument.close[...-1])
    context.init_done = true

  bar = instrument.ticks[data_length-1]

  context.macd.update(bar.close)

  trigger_buy  = false
  trigger_sell = false

  # Buy signal
  if (context.macd.signal_crossover > 0 and
      context.macd.macd > g.macd_sigcross_buy_thresh)
    trigger_buy = true

  # Sell signal
  if (context.macd.signal_crossover < 0 and
      context.macd.macd < g.macd_sigcross_sell_thresh)
    trigger_sell = true

  if trigger_sell and portfolio.positions[instrument.asset()].amount > 0
      sell instrument # Sell asset position
  if trigger_buy and portfolio.positions[instrument.curr()].amount > 0
      buy instrument # Spend all amount of cash for asset
