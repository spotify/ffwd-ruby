# Lifecycle management module.
#
# Any class and module including this will allow other components to subscribe
# to their state changes (starting, stopping).
module FFWD
  module Lifecycle
    def stopping_hooks
      @stopping_hooks ||= []
    end

    def starting_hooks
      @starting_hooks ||= []
    end

    # Register a callback to be executed when the Stoppable is to be stopped.
    # 
    # This will only be called once.
    def stopping &block
      if stopped?
        block.call
      else
        stopping_hooks << block
      end
    end

    def starting &block
      if started?
        block.call
      else
        starting_hooks << block
      end
    end

    def start
      return if started?
      starting_hooks.each(&:call)
      starting_hooks.clear
      @state = :started
    end

    def stop
      return if stopped?
      stopping_hooks.each(&:call)
      stopping_hooks.clear
      @state = :stopped
    end

    def started?
      (@state ||= :none) == :started
    end

    def stopped?
      (@state ||= :none) == :stopped
    end

    def depend_on other_lifecycle
      if other_lifecycle.nil?
        raise "Other lifecycle must not be nil"
      end

      if (@depends ||= nil)
        raise "This component already depends on #{@depends}"
      end

      @depends = other_lifecycle

      other_lifecycle.starting do
        start
      end

      other_lifecycle.stopping do
        stop
        @depends = nil
      end
    end
  end
end
