module Gripen::Handler
  # Base handler.
  private module Base(H)
    # Next handler to execute after this one.
    property next : H? = nil

    # Adds a handler at the trailing `#next` handler.
    def <<(handler : H)
      if next_handler = @next
        next_handler << handler
      else
        @next = handler
      end
      self
    end
  end
end
