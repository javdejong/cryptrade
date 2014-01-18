require "underscore"
fs = require "fs"
CoffeeScript = require 'coffee-script'
CSON = require 'cson'
basename = require('path').basename
Trader = require './trader'
logger = require 'winston'
Fiber = require 'fibers'
deepclone = require('./utils').deepclone

# TODO: Also make logger log to file? Although not really necessary for backtesting
logger.remove logger.transports.Console
logger.add logger.transports.Console,{level:'info',colorize:true,timestamp:true}

if require.main == module
  program = require('commander')
  program
    .usage('[options] <data.json> <script.coffee>')
    .option('-c,--config [value]','Load configuration file')
    .option('-i,--instrument [value]','Trade instrument (ex. btc_usd)')
    .option('-s,--initial [value]','Number of trades that are used for initialization (ex. 248)',parseInt)
    .option('-p,--portfolio <asset,curr>','Initial portfolio (ex. 0,5000)',(val)->val.split(',').map(Number))
    .option('-f,--fee [value]','Fee on every trade in percent (ex. 0.5)',parseFloat)
    .parse process.argv

  config = CSON.parseFileSync './config.cson'

  # TODO: make this a separate option.
  #       That way, when the user does not have to specify the trade data
  #       directly, the platform to use for backtesting can be specified
  config.platform = "backtest"

  # TODO: Cannot simulate the check order interval just yet. See trader.coffee
  config.check_order_interval = 0

  if program.config?
    logger.info "Loading configuration file configs/#{program.config}.cson.."
    anotherConfig = CSON.parseFileSync 'configs/'+program.config+'.cson'
    config = _.extend config,anotherConfig

  if program.args.length > 2
    logger.error "Too many arguments"
    process.exit 1

  if program.args.length < 2
    logger.error "Filename to trader source and/or data source not specified"
    process.exit 1

  source = program.args[1]
  code = fs.readFileSync source,
    encoding: 'utf8'
  name = basename source,'.coffee'
  unless code?
    logger.error "Unable load source code from #{source}"
    process.exit 1

  # Load trade data
  # TODO: Use csv data, and let the user specify platform (mtgox,btce) and start/end times
  datafile = program.args[0]
  data = fs.readFileSync datafile,
    encoding: 'utf8'
  unless data?
    logger.error "Unable load trade data from #{datafile}"
    process.exit 1
  data = JSON.parse(data)

  newdatatype = false
  if data instanceof Array
    newdatatype = true

  # Configuration of other options
  config.instrument = program.instrument or config.instrument
  config.init_data_length = program.initial or config.init_data_length
  pl = config.platforms[config.platform]
  pl.fee = program.fee or pl.fee
  if program.portfolio?
    for x,i in config.instrument.split('_')
      pl.initial_portfolio[x] = program.portfolio[i]

  script = CoffeeScript.compile code,
    bare:true
  logger.info 'Starting backtest...'

  # Intialize a trader instance, no key
  trader = new Trader name,config,null,script

  # Ready the initial data
  elems = ["open", "close", "high", "low", "volumes", "ticks"]

  # TODO: Old code, we can probably get rid of it
  if not newdatatype
    instrument = data[config.instrument]
    data.instruments[0] = instrument # Fix the reference

    length_end = instrument.open.length

    temp = deepclone(data) # We don't want to ruin the original data
    temp_instrument = temp[config.instrument]

    for el in elems
      t = instrument[el]
      temp_instrument[el] = t[...config.init_data_length]

    last_i = temp_instrument.close.length - 1 # Asserted that all arrays are of equal length

    temp_instrument["price"] = temp_instrument.close[last_i]
    temp_instrument["volume"] = temp_instrument.volumes[last_i]
    temp.at = temp_instrument.ticks[last_i].at
  else
    length_end = data.length

  Fiber =>
    # Initialize the trader with the initial data
    if not newdatatype
      # TODO: old code, get rid of it
      bars = deepclone temp_instrument.ticks
    else
      bars = deepclone data

    trader.init(bars)


    # Gradually extend the object
    for i in [config.init_data_length...length_end-1]
      # Array stuff
      if not newdatatype
        # TODO: old code, get rid of it
        for el in elems
          a = instrument[el]
          b = temp_instrument[el]

          o = deepclone(a[i])
          b.push(o)

        # Non-array stuff
        last_i = temp_instrument.close.length - 1 # Asserted that all arrays are of equal length

        temp_instrument["price"] = temp_instrument.close[last_i]
        temp_instrument["volume"] = temp_instrument.volumes[last_i]
        temp.at = temp_instrument.ticks[last_i].at

        # Trader gets the last bar = tick
        bar = temp_instrument.ticks[last_i]
      else
        bar = data[i]
      bar.instrument = config.instrument
      trader.handle bar
  .run()
