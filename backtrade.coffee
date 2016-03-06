_ = require "underscore"
fs = require "fs"
CoffeeScript = require 'coffee-script'
CSON = require 'cson'
basename = require('path').basename
Trader = require './trader'
logger = require 'winston'
Fiber = require 'fibers'
deepclone = require('./utils').deepclone
vm = require 'vm'
uneval = require 'uneval'
Population = require './population'

# TODO: Also make logger log to file? Although not really necessary for backtesting
logger.remove logger.transports.Console
logger.add logger.transports.Console,{level:'warning',colorize:true,timestamp:true}


if require.main == module
  program = require('commander')
  program
    .usage('[options] <data.json> <script.coffee>')
    .option('-c,--config [value]','Load configuration file')
    .option('-i,--instrument [value]','Trade instrument (ex. btc_usd)')
    .option('-s,--initial [value]','Number of trades that are used for initialization (ex. 248)',parseInt)
    .option('-p,--portfolio <asset,curr>','Initial portfolio (ex. 0,5000)',(val)->val.split(',').map(Number))
    .option('-f,--fee [value]','Fee on every trade in percent (ex. 0.5)',parseFloat)
    .option('-g,--genetic <popSize,genSize>','Use genetic algorithm for optimization [0,0]', (val)->val.split(',').map(Number))
    .parse process.argv

  config = CSON.parseCSONFile './config.cson'

  # TODO: make this a separate option.
  #       That way, when the user does not have to specify the trade data
  #       directly, the platform to use for backtesting can be specified
  config.platform = "backtest"

  # TODO: Cannot simulate the check order interval just yet. See trader.coffee
  config.check_order_interval = 0

  if program.config?
    logger.info "Loading configuration file configs/#{program.config}.cson.."
    anotherConfig = CSON.parseCSONFile 'configs/'+program.config+'.cson'
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

  initTrader = ->
    trader = new Trader name,config,null,script
    trader

  runTrader = (trader) ->
    # Initialize the trader with the initial data
    trader.init(data[...config.init_data_length])

    # Gradually extend the object
    for bar in data[config.init_data_length..]
      # Array stuff
      bar.instrument = config.instrument
      trader.handle bar


  if program.genetic?
    populationSize = Math.max(program.genetic[0], 1)
    generationSize = Math.max(program.genetic[1], 1)

    Fiber =>
      population = new Population populationSize, initTrader, runTrader

      for i in [1...generationSize]
        population.nextGeneration()
    .run()
  else
    Fiber =>
      trader = initTrader()
      runTrader(trader)

      console.log("Finished backtest!")

      p = trader.sandbox.portfolio.positions
      a = undefined;
      for x of trader.sandbox.portfolio.positions
        console.log("#{x.toUpperCase()}: #{p[x].amount}")
        a = x.toUpperCase()

      console.log("(#{trader.getWorthInCurr()} #{a})")

    .run()
