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
    .usage('[options] --script <script.coffee> <data.json> <moredata.json>')
    .option('-c,--config [value]','Load configuration file')
    .option('-a,--script [value]','Location of trading algorithm.')
    .option('-i,--instrument [value]','Trade instrument (ex. btc_usd)')
    .option('-s,--initial [value]','Number of trades that are used for initialization (ex. 248)',parseInt)
    .option('-p,--portfolio <asset,curr>','Initial portfolio (ex. 0,5000)',(val)->val.split(',').map(Number))
    .option('-f,--fee [value]','Fee on every trade in percent (ex. 0.5)',parseFloat)
    .option('-g,--genetic <popSize,genSize[,genDecrease,minGenSize]>','Use genetic algorithm for optimization [0,0]', (val)->val.split(',').map(Number))
    .option('-b,--begin [value]','Datetime to start the backtest',Date.parse)
    .option('-e,--end [value]','Datetime to end the backtest (exclusive)',Date.parse)
    .option('-m,--mean [value]','Mean method [arithmetic, geometric, harmonic]', 'harmonic')
    .option('-v, --verbose', 'Verbosity level (can be increased by repeating)', ((v, total) -> total + 1), 0)
    .parse process.argv

  if program.verbose?
    if program.verbose >= 2
      logger.level = 'debug'
    else if program.verbose >= 1
      logger.level = 'info'
  else
    logger.level ='warn'

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

  unless program.script?
    logger.error "Please specify trading algorithm/script to backtest."
    process.exit 1

  if program.args.length < 1
    logger.error "Please specify at least one data source."
    process.exit 1

  source = program.script
  code = fs.readFileSync source,
    encoding: 'utf8'

  name = basename source,'.coffee'
  unless code?
    logger.error "Unable load source code from #{source}"
    process.exit 1

  # Configuration of other options
  config.instrument = program.instrument or config.instrument
  config.init_data_length = program.initial or config.init_data_length
  pl = config.platforms[config.platform]
  pl.fee = program.fee or pl.fee

  [asset, curr] = config.instrument.split('_')

  if program.portfolio?
    for x,i in config.instrument.split('_')
      pl.initial_portfolio[x] = program.portfolio[i]

  # Load trade data
  # TODO: Use csv data, and let the user specify platform (mtgox,btce) and start/end times
  all_data = []
  all_interval = null
  for datafile in program.args
    data = fs.readFileSync datafile,
      encoding: 'utf8'
    unless data?
      logger.error "Unable load trade data from #{datafile}"
      process.exit 1
    data = JSON.parse(data)

    # Only slice the amount of data that we need
    interval = data[1].at - data[0].at
    if all_interval? and interval != all_interval
      logger.warn "Interval of #{datafile} (#{interval/1000} s) does not match the previously found interval of #{all_interval/1000} s."
    unless all_interval?
      all_interval = interval

    if program.begin?
      start_index = parseInt((program.begin - data[0].at)/interval)
      start_index = start_index - config.init_data_length
      if start_index < 0
        throw new Error("No data available in selected period", datafile)

      data = data[start_index..]

    if program.end?
      end_index = parseInt((program.end - data[0].at)/interval)
      # Exclusive, so do not include the bar for the period [end,end+1],
      # which finds itself in our data at t = end.
      end_index = end_index - 1
      if end_index > data[data.length-1]
        throw new Error("No data available in selected period", datafile)
      data = data[..end_index]

    all_data.push(data)

  script = CoffeeScript.compile code,
    bare:true
  logger.info 'Starting backtest...'

  initTrader = ->
    trader = new Trader name,config,null,script
    trader

  runTrader = (trader, data) ->
    # Initialize the trader with the initial data. This is one fewer than the
    # amount of data,  because we make the first call to handle() have exactly
    # the right number of elements.
    trader.init(data[...config.init_data_length-1])

    # Gradually extend the object
    for bar in data[config.init_data_length-1..]
      # Array stuff
      bar.instrument = config.instrument
      trader.handle bar

  getBuyHoldWorth = (data) ->
    init_price = data[config.init_data_length-1].close
    last_price = data[data.length-1].close

    amnt_asset = pl.initial_portfolio[asset] + pl.initial_portfolio[curr] / init_price
    cur_worth = amnt_asset * last_price
    cur_worth

  logFinalStats = (cur_worth, data, positions) ->
    if positions?
      for x of positions
        console.log("#{x.toUpperCase()}: #{positions[x].amount}")

    cur_worth = Math.round(1e6 * cur_worth) / 1e6
    eff_buyhold = Math.round(1000 * cur_worth / getBuyHoldWorth(data)) / 1000
    console.log("(Total: #{cur_worth} #{curr.toUpperCase()})")
    console.log("Efficiency: #{eff_buyhold}x")

  if program.genetic?
    populationSize = Math.max(program.genetic[0], 1)
    generationSize = Math.max(program.genetic[1], 1)

    popDecrease = 1.0
    minPop = populationSize

    if program.genetic.length == 4
      popDecrease = program.genetic[2]
      minPop = program.genetic[3]

    Fiber =>
      population = new Population populationSize, initTrader, runTrader, all_data, program.mean, popDecrease, minPop

      for i in [1...generationSize]
        population.nextGeneration()

      winner = population.genomes[population.genomes.length-1]
      cur_worth = winner.cost()

      logFinalStats(cur_worth, data)

    .run()
  else
    Fiber =>
      for data in all_data
        trader = initTrader()
        runTrader(trader, data)

        console.log("Finished backtest!")

        p = trader.sandbox.portfolio.positions

        logFinalStats(trader.getWorthInCurr(), data, p)
    .run()
