
# -*- ruby -*-

# Invocations are drop-in replacements for other functions (such as
# procs/blocks, lambdas, methods, etc).
#
# They differ in that they are self-currying, allow partial evaluation with
# arbitrary argument ordering, and allow non-keyword arguments to be given as
# keywords.
#
class Invocation
  %i(call yield []).each { |name| singleton_class.send :alias_method, name, :new }

  # Creates a new Invocation.
  #
  # @param callable [#call] a proc-like object
  #
  # @raise [ArgumentError] if neither a callable object nor a block is provided.
  #
  # @return [Invocation] a new instance of Invocation
  #
  def initialize(callable = nil, *rest, **state, &block)
    raise ::ArgumentError, "#{self.class}##{__callee__} requires a callable object or a block" unless (callable.respond_to?(:call) || block)

    if callable.respond_to? :call
      @function = callable
      @block    = block
    else
      @function = block
    end

    @state = state
    @rest = rest

    %i(required optional inferences unassigned arguments keywords).each { |method| send method }

    self
  end

  attr_reader :function, :state

  # Which parameters are required?
  #
  # @return [Array<Symbol>] the required parameters of the function
  #
  def required
    @required ||= (
      required_arguments = function_parameters(:req)
      required_keywords  = function_parameters(:keyreq)
      needed = function_arity - (required_arguments.length + (required_keywords.length > 0 ? 1 : 0))

      @required = function_parameters(:opt, :key).take(needed) + required_arguments + required_keywords
    )
  end

  # Which parameters are optional?
  #
  # @return [Array<Symbol>] the optional parameters of the function
  #
  def optional
    @optional ||= function_parameters(:opt, :key)
                    .drop(function_arity - function_parameters(:req).length)
  end

  # Which parameters can be inferred from arguments?
  #
  # @return [Hash<Symbol, Object>] the inferred association of non-keyword
  #   arguments to parameter names.
  #
  def inferences
    @inferences ||= if @rest.empty?
                      {}
                    else
                      (function_parameters(:req, :opt) - @state.keys)
                        .map
                        .with_index { |argument, index| [argument, @rest[index]] if index < @rest.length }
                        .compact
                        .to_h
                    end
  end

  # Which arguments are not assigned to known parameters?
  #
  # @return [Array] the arguments that are not assigned to parameters.
  #
  def unassigned
    @unassigned ||= @rest.drop(inferences.length)
  end

  # Which parameters have been provided?
  #
  # @return [Hash<Symbol, Object>] all known parameters provided for the function.
  #
  def known
    @known ||= @state.merge(inferences)
  end

  # Which parameters are missing?
  #
  # @return [Array<Symbol>] the names of any missing parameters.
  def missing
    @missing ||= required - known.keys
  end

  # What are the arguments?
  #
  # @return [Array] the provided arguments for the function.
  def arguments
    @arguments ||= function_parameters(:req, :opt, :rest)
                     .map { |argument| known[argument] }
  end

  # What are the keywords?
  #
  # @return [Hash<Symbol, Object>] the provided keywords for the functino.
  #
  def keywords
    @keywords ||= function_parameters(:keyreq, :key, :keyrest)
                    .map { |keyword| [keyword, known[keyword]] if known.key?(keyword) }
                    .compact
                    .to_h
  end

  # How will the function be called?
  #
  # @return Array the list of arguments that will be used to call the function.
  #
  def invocation(*rest, **keyrest)
    @invocation ||= [*[*arguments, *unassigned].compact, *rest, *[**keywords.merge(keyrest)].reject(&:empty?)]
  end

  # Is the function ready to be called?
  #
  # @return [Boolean] if this Invocation has all required parameters specified.
  #
  def prepared?
    missing.empty?
  end

  # Prepares an Invocation, without calling it.
  #
  # @return [Invocation] a new Invocation populated with the parameters given.
  #
  def prepare(*rest, **keyrest, &block)
    self.class.new(@function, *[*unassigned, *rest], **known.merge(keyrest), &(block || @block))
  end

  # Prepares an Invocation, and invokes it if able.
  #
  # If the provided parameters produce a properly prepared Invocation, it will
  # be invoked. Otherwise, it will be returned.
  #
  # @note This is very similar to how #call works with a curried Proc.
  #
  def call(*rest, **keyrest, &block)
    if block || [rest, keyrest].all?(&:empty?)
      prepared? ? invoke : self
    else
      function = prepare(*rest, **keyrest, &block)
      function.prepared? ? function.send(:invoke) : function
    end
  end

  alias [] call
  alias yield call

  # How many additional parameters are needed?
  #
  # @return [Integer] the number of required parameters.
  #
  # @note when multiple keyword parameters are required, they count as one
  #   parameter. This is consistent with other Ruby functions (Proc, etc).
  #
  def arity
    @arity ||= (
      required_keywords = function_parameters(:keyreq)
      missing_keywords  = required_keywords - known.keys
      (missing - required_keywords).length + (missing_keywords.length > 0 ? 1 : 0)
    )
  end

  # Converts the Invocation into a Proc
  #
  # @return [Proc] a Proc that calls the Invocation with any parameters given.
  #
  def to_proc
    proc { |*rest, **keyrest, &block| self.(*rest, **keyrest, &block) }
  end

  # Converts the Invocation into a curried Proc.
  #
  # @return [Proc] a Proc, curried with the arity of the Invocation.
  #
  def curry(n = arity)
    to_proc.curry(n)
  end

  # Is the Invocation a lambda?
  #
  # @return [false] false, always.
  #
  # @note An Invocation is not a lambda, as it does not handle arguments
  # strictly. It is semantically much more proc-like.
  #
  def lambda?
    false
  end

  # Which parameters have not been provided?
  #
  # @return [Array<Symbol, Symbol>] the remaining parameters of the function.
  #
  def parameters
    @function.parameters.reject { |_, name| known.keys.include? name }
  end

  ####################
  # Internal Methods #
  ####################

  private

  # Invokes the function.
  #
  # @note This is used internally to call the function. A return cannot be
  # specified, because it depends entirely on the function this Invocation was
  # created with.
  #
  def invoke(*rest, **keyrest, &block)
    @function.(*invocation(*rest, **keyrest), &(block || @block))
  end

  # How many parameters does the function require?
  #
  # @return [Integer] The arity of the initial function.
  #
  # @note this is for internal use, and is *not* strictly equivalent to
  #   function.arity. For example, it always returns a non-negative value.
  #
  def function_arity
    @function.arity.positive? ? @function.arity : @function.arity.succ.abs
  end

  # What are the names of the parameters of certain types?
  #
  # @return [Array<Symbol>] the names of parameters matching the given types.
  #
  def function_parameters(*types)
    @function.parameters
      .select { |type, _| types.include? type }
      .flat_map(&:last)
  end
end
