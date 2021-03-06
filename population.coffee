Genome = require './genome'
_ = require 'underscore'
MersenneTwister = require('mersenne-twister')
generator = new MersenneTwister(42)

# Base class for ranking and creating populations
class Population
  # @property [Array<Genome>] All the genomes of this population
  genomes: []

  # @property [Float] The chance of a Genome to mutate (based on its current values)
  smallMutationChance: .4

  # @property [Float] The chance of a Genome to mutate (based on the originally specified range)
  bigMutationChance: .05

  # @property [Boolean] If true, the two best Genomes will survive without mutation or mating
  elitism: true

  mutateEliteInsteadChance: .05

  # @property [Float] Determines the maximum amount of values to be copied from parents
  mixingRatio: .8

  # @property [Integer] The number of the current generation
  currentGeneration: 0

  # @property [Integer] The number of participants for the tournament selection
  tournamentParticipants: 4

  # @property [Float] The chance of having a tournament selection
  tournamentChance: .1

  afterGeneration: ->
    console.log("Round ##{@currentGeneration}:")
    console.log(@genomes[@genomes.length-1].cost())
    console.log(@genomes[@genomes.length-1].values)


  # @param [Integer] populationSize The size of the population
  # @param [Integer] maxGenerationCount The maximum number of generations (iterations)
  constructor: (@populationSize = 1000, @traderInit, @traderRun, @all_data, @mean_method="harmonic", @popDecrease = 1.0, @minPop) ->
    if not @minPop?
      @minPop = @populationSize
    @_targetPopSize = @populationSize

    @genomes.push new Genome(null, @traderInit, @traderRun, @all_data, @mean_method) for i in [0...@populationSize]
    @rank()
    @afterGeneration()


  # Ranks all genomes according to their cost (higher is better)
  rank: ->
    @genomes = _.sortBy @genomes, (genome) -> genome.cost()

  # @return [Genome] the best Genome in this population
  best: ->
    _.last(@genomes)

  # @return [Genome] the worst Genome in this population
  worst: ->
    _.first(@genomes)

  # Selects a Genome by tournament selection. The amount of participants is defined by
  # @tournamentParticipants.
  # @return [Genome] the Genome which has won the tournamen selection
  tournamentSelect: ->
    participants = []
    # select random participants
    for index in [0..@tournamentParticipants]
      randomIndex = Math.floor @genomes.length * generator.random_long()
      participants.push @genomes[randomIndex]
    # rank participants
    participants = _.sortBy participants, (genome) -> genome.cost()
    participants[participants.length - 1]

  # Creates the next generation
  nextGeneration: ->
    nextGeneration = []
    skip = 0
    @currentGeneration++

    # the fittest two survive
    if @elitism
      nextGeneration.push(@genomes[@genomes.length - 1])
      nextGeneration.push(@genomes[@genomes.length - 2])
      skip = 2

    @_targetPopSize = Math.max(@_targetPopSize * @popDecrease, @minPop)
    newSize = parseInt(@_targetPopSize)

    start = @genomes.length - newSize + skip

    for index in [start...@genomes.length] by 2
      if generator.random_long() < @mutateEliteInsteadChance
        # Just mutate the elite two instead of doing crossovers
        c1 = Genome.small_mutate(@genomes[@genomes.length - 1].values, @genomes[@genomes.length - 1].origvalues)
        c2 = Genome.small_mutate(@genomes[@genomes.length - 2].values, @genomes[@genomes.length - 2].origvalues)
      else
        # do a tournament selection
        a = @tournamentSelect()
        b = @tournamentSelect()

        origvalues = a.origvalues # Aren't mutated

        # perform a crossover if the maximum hasn't been reached
        curMix = @mixingRatio * generator.random_long()
        children = Genome.crossover(a.values, b.values, curMix)
        c1 = children[0]
        c2 = children[1]

        force_mutate = curMix <= (1 / ((x for x,y of a.values).length)) # In this case, the cross-over did not do anything

        # mutate the genomes
        c1 = Genome.small_mutate(c1, origvalues) if (generator.random_long() < @smallMutationChance or force_mutate)
        c2 = Genome.small_mutate(c2, origvalues) if (generator.random_long() < @smallMutationChance or force_mutate)

        # An even bigger mutation (entire re-evaluation)
        c1 = Genome.small_mutate(c1, origvalues) if generator.random_long() < @bigMutationChance
        c2 = Genome.small_mutate(c2, origvalues) if generator.random_long() < @bigMutationChance

      # add the new genomes to the next generation
      nextGeneration.push(new Genome(c1, @traderInit, @traderRun, @all_data, @mean_method))
      nextGeneration.push(new Genome(c2, @traderInit, @traderRun, @all_data, @mean_method))

    @genomes = nextGeneration

    @rank()

    @afterGeneration()

module.exports = Population
