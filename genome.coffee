# Base class for a Genome.
# 
# Genomes are able to mate and mutate. 
# They contain the logic to get a so called cost which is needed to compare
# a Population.
deepclone = require('./utils').deepclone

class Genome

  # @property [Array] This genome's values
  values: {}

  # If no values are given, it defaults to `@initial()`
  constructor: (@values, traderInit, traderRun) ->
    trader = traderInit()

    conf = trader.getGA()

    @origvalues = deepclone(conf)
    
    if conf?
      if @values?
        conf = @values     
      else    
        conf = @initial(conf)      

    traderRun(trader)
    @score = trader.getWorthInCurr()


  set_value_interval: (conf,a) ->

    random_interval = (from,to) ->
      Math.random() * (to - from) + from

    b = conf[a]
    conf[a] = b[2](random_interval(b[0],b[1]))    


  # Creates the initial set of values
  # @return [Array]
  initial: (conf) ->

    for a of conf
      @set_value_interval(conf,a)

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
  # Mutate this genome by reavaluating a random element
  mutate: (values) ->
    value_names = (a for a,b of values)
    index = @getRandomIndex(value_names)
    item_name = value_names[index]
    values[item_name] = deepclone(@origvalues[item_name])
    set_value_interval(values,item_name)

  # Perform a uniform crossover with the given genome
  # A mixingratio of 1.0 means that half/half are mixed. So we divide by two below
  # @param [Genome] genome 
  # @param [Float] mixingRatio How much should get mixed?
  # @return [Array<Object>] the two new Value objects

  crossover: (genome, mixingRatio) ->
    value_names = (a for a,b of @values)

    cpP1 = deepclone @values
    cpP2 = deepclone genome.values


    # Copy original values
    for i in [0...value_names.length]
      if (i / value_names.length) > (mixingRatio / 2.0)
        break

      index = @getRandomIndex value_names
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
  getRandomIndex: (array) ->
    Math.floor(array.length * Math.random())

module.exports = Genome
