
# -*- ruby -*-

require_relative 'invocations/invocation'

# This module refines Kernel, adding "invocation" and "Invocation" as methods.
module Invocations
  refine Kernel do
    # Creates a new Invocation with the provided parameters
    def invocation(*rest, **keyrest, &block)
      ::Invocation.new(*rest, **keyrest, &block)
    end

    alias_method :Invocation, :invocation
  end
end

