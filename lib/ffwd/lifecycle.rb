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
      raise "Cannot register callback hook if already stopped" if stopped?
      stopping_hooks << block
    end

    def starting &block
      raise "Cannot register callback hook if already started" if started?
      starting_hooks << block
    end

    def start
      return if started?
      starting_hooks.each(&:call)
      starting_hooks.clear
      @started = true
    end

    def stop
      return if stopped?
      stopping_hooks.each(&:call)
      stopping_hooks.clear
      @stopped = true
    end

    def started?
      @started ||= false
    end

    def stopped?
      @stopped ||= false
    end
  end
end
