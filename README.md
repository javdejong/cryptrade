cryptrade
=========

NodeJS trading client based Cryptotrader.org

Cryptrade is a standalone client for Cryptotrader.org. The current focus is on the backtesting and optimization capabilities, and the live trading functionaly is likely to be broken.

## Features
  - Support for 125+ [Talib](http://ta-lib.org/) indicators such as EMA, MACD, etc.
  - Compatible with Cryptotrader.org API

## Installation
  - Make sure you have [Node](http://nodejs.org/) installed
  - Install cryptrade tool

        git clone https://github.com/javdejong/cryptrade.git
        cd cryptrade
        npm install

  For the live trader (if it still works)
    - Open keys.cson and put your API keys of the exchanges you want to trade on. *Private keys are never sent to the server.* If after installation keys.cson file doesn't exist, then something went wrong during the installation and you need to check the logs.

## Windows
  It is possible to use this repository on Windows. The only change you need to make is to the "talib_sync.coffee" file. Replace
    require 'talib'
  with
    require './talib-win64'

## Backtesting
  To test whether your algorithm works as intended, you can use the backtrader. You can supply multiple data sources, and it will run the backtrader for all those sources, and average the results. It is also possible to run the backtrader for only a subset of the period, by specifying the beginning and end period.

    Usage: backtrade.coffee [options] --script <script.coffee> <data.json> <moredata.json>

    Options:

      -h, --help                                               output usage information
      -c,--config [value]                                      Load configuration file
      -a,--script [value]                                      Location of trading algorithm.
      -i,--instrument [value]                                  Trade instrument (ex. btc_usd)
      -s,--initial [value]                                     Number of trades that are used for initialization (ex. 248)
      -p,--portfolio <asset,curr>                              Initial portfolio (ex. 0,5000)
      -f,--fee [value]                                         Fee on every trade in percent (ex. 0.5)
      -g,--genetic <popSize,genSize[,genDecrease,minGenSize]>  Use genetic algorithm for optimization [0,0]
      -b,--begin [value]                                       Datetime to start the backtest
      -e,--end [value]                                         Datetime to end the backtest (exclusive)
      -m,--mean [value]                                        Mean method [arithmetic, geometric, harmonic]
      -v, --verbose                                            Verbosity level (can be increased by repeating)

## Genetic optimization
  To take the backtesting one step further, you can use genetic optimization to tune the parameters for you. This is by far no magic, and you yourself will have to make sure that you are not overfitting the data. You can use multiple data sources to limit the amount of overfitting.

  The repository should have all the data available for you to run the following command, to get a feeling for what it does.

    coffee .\backtrade.coffee -p 0,1000 -f 0.5 -s 100 -b "2014-10-01" -i btc_usd -m "harmonic" -g 50,5,0.9,20 -a .\examples\genetic_optimization.coffee .\ohlc\bitfinex_btc_usd_2h_20140401_20160328.json .\ohlc\btce_btc_usd_2h_20140401_20160328.json .\ohlc\bitstamp_btc_usd_2h_20140401_20160328.json

  Using TA-lib functions is slow, and I would suggest you not use them for genetic optimization. The reason they are slow, is that they recalculate from scratch at every tick. An EMA for example is however nothing more than "new_ema = old_ema * (1-alpha) + cur_val * alpha". In other words, it depends on nothing more than the current tick, and the previous tick. This makes computation a lot faster. See examples/genetic_optimization.coffee for a simple implementation of MACD and EMA.

## Live trading
  Live trading is untested, and likely to be broken!

  To start trading bot, just type

    ./cryptrade.sh https://cryptotrader.org/backtests/PqS7WC4NXv6PiF3RD

  The above command will start EMA 10/21 algorithm to trade at Mtgox BTC/USD with trading period set to 1h.
  Also, you can run the tool with an algorithm stored locally. In this case your algorithm won't be sent to the server:

    ./cryptrade.sh examples/ema_10_21.coffee


   Default configuration can be overriden by command line options:

    Usage: cryptrade.coffee [options] <filename or backtest url in format https://cryptotrader.org/backtests/<id>>

    Options:

      -h, --help               output usage information
      -c,--config [value]      Load configuration file
      -p,--platform [value]    Trade at specified platform
      -i,--instrument [value]  Trade instrument (ex. btc_usd)
      -t,--period [value]      Trading period (ex. 1h)

  For example, to start the above algorithm at Bitstamp with trading period set to 2 hours use the following command:

    ./cryptrade.sh -p bitstamp -t 2h examples/ema_10_21.coffee

**This is beta software, use it at your own risk**
