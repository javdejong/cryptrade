# Base class for a Genome.
#
# Genomes are able to mate and mutate.
# They contain the logic to get a so called cost which is needed to compare
# a Population.
deepclone = require('./utils').deepclone
MersenneTwister = require('mersenne-twister')
generator = new MersenneTwister(42)

class Genome

  # @property [Array] This genome's values
  values: {}

  # If no values are given, it defaults to `@initial()`
  constructor: (@values, traderInit, traderRun, all_data) ->
    trader = traderInit()

    conf = trader.context.gconfig

    # Somewhat of a hack. Store original functions to be able to mutate ourselves when done.
    @origvalues = deepclone(conf)

    if conf?
      if @values?
        for a of conf
          conf[a] = @values[a]
      else
        conf = @initial(conf)


    @score = 0

    for data in all_data
      curtrader = traderInit()
      curconf = curtrader.context.gconfig

      if conf?
        for a of conf
          curconf[a] = conf[a]

      traderRun(curtrader, data)
      @score = @score + curtrader.getWorthInCurr()
      curtrader.clean()

    @score = @score / all_data.length

    trader.clean()

  @set_value_interval: (conf,a) ->

    random_interval = (from,to) ->
      generator.random_long() * (to - from) + from

    b = conf[a]
    try
      conf[a] = b[2](random_interval(b[0],b[1]))
    catch error
      throw new Error(error)


  # Creates the initial set of values
  # @return [Array]
  initial: (conf) ->

    for a of conf
      Genome.set_value_interval(conf,a)

    @values = conf



  # Compares this genome to the given genome.
  # Comparison is based on cost and therefore a lower cost is better.
  # @param [Genome] genome The genome you want to compare to this one
  # @return [Integer] Returns 1 if this one is better, -1 if the other one is better or 0 when they're the same
  # when they have the same cost

  ###
  compare: (genome) ->
    costThis = @cost()
    costThat = genome.cost()
    if costThis is costThat
      0
    else if costThis < costThat
      1
    else
      -1
  ###

  # Class methods for mutating and cross overs.
  # All these functions are non-destructive on their input parameters

  # "Small mutate" uses the passed-in value, and perturbs it a little.
  # The "big mutate" function instead re-evaluates the GConfig line,
  # not caring at all about the current value.

  @small_mutate: (values, origvalues, frac) ->
    values = deepclone(values)  # Non-destructive

    if not frac?
      frac = 0.5
    value_names = (a for a,b of values)
    index = Genome.getRandomIndex(value_names)
    item_name = value_names[index]

    b = origvalues[item_name]

    newval = values[item_name] * (frac + 2*frac * generator.random_long())
    # Make sure the perturbed value is still in the allowed range
    newval = Math.min(newval, b[1])
    newval = Math.max(newval, b[0])

    newval = b[2](newval)

    values[item_name] = newval
    values


  @big_mutate: (values, origvalues) ->
    values = deepclone(values) # Non-destructive

    value_names = (a for a,b of values)
    index = Genome.getRandomIndex(value_names)
    item_name = value_names[index]
    values[item_name] = deepclone(origvalues[item_name])  # TODO: Check if the clone here is really necessary
    Genome.set_value_interval(values, item_name)
    values

  # Perform a uniform crossover with the given genome
  # A mixingratio of 1.0 means that half/half are mixed. So we divide by two below
  # @param [Genome] genome A's values
  # @param [Genome] genome B's values
  # @param [Float] mixingRatio How much should get mixed?
  # @return [Array<Object>] the two new Value objects
  @crossover: (values_a, values_b, mixingRatio) ->
    value_names = (a for a,b of values_a)

    cpP1 = deepclone values_a
    cpP2 = deepclone values_b

    # Copy original values
    for i in [0...value_names.length]
      if (i / value_names.length) > (mixingRatio / 2.0)
        break

      index = Genome.getRandomIndex value_names
      item_name = value_names[index]
      # Switch
      temp = cpP1[item_name]
      cpP1[item_name] = cpP2[item_name]
      cpP2[item_name] = temp

      # And remove this fieldname from the array so we don't choose it again
      value_names.splice(index, 1)

    return [cpP1, cpP2]


  # The cost function is used to compare genomes. The cost is described as a measure of how optimal a
  # Genome is. Sometimes this function also called `fitness` function.
  #
  # In this case, the cost is the sum of the length of all routes for this genome.
  #
  # @return [Integer] the cost for this genome
  cost: ->
    return @score

  # Checks if the Genome contains all cities
  # @return [Boolean]
  isValid: ->
    return true

  # Helper function which returns a random index from the given array
  @getRandomIndex: (array) ->
    Math.floor(array.length * generator.random_long())

module.exports = Genome
