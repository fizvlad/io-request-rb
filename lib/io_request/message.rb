module IORequest
  # Message to other side of IO.
  class Message
    # @return [Integer] ID of message.
    attr_reader :id
    alias_method :to_i, :id

    # @return [Hash] stored data.
    attr_reader :data

    # Initialize new message.
    #
    # @param data [Hash]
    # @param id [Integer, nil] if +nil+ provided {Message.generate_id} will be
    #   used to generate random id.
    def initialize(data, id = nil)
      @id = id || Message.generate_id
      @data = data
    end

    # @return [String] human-readable form.
    def to_s
      "#{self.class.name}##{@id}: #{@data.inspect}"
    end

    # @return [Integer] random numerical ID based on current time and random salt.
    def self.generate_id
      ((rand(999) + 1) * Time.now.to_f * 1000).to_i % 2**32
    end
  end

  # Request for server or client.
  class Request < Message
    # Amount of time to sleep before checking whether responded.
    JOIN_SLEEP_TIME = 0.5

    # @return [Integer, Response, nil] ID of response or response itself for this message.
    attr_reader :response

    # @!visibility private
    attr_writer :response

    # Initialize new request.
    #
    # @param data [Hash]
    # @param response [Integer, Response, nil]
    # @param id [Integer, nil]
    def initialize(data, response = nil, id = nil)
      @response = response
      super(data, id)
    end

    # @return [String] human readable form.
    def to_s
      "#{super.to_s}; #{@response ? "Response ID: #{@response.to_i}" : "Not responded"}"
    end

    # Freezes thread until request is responded or until timeout expends.
    #
    # @param timeout [Integer, Float, nil] timeout size or +nil+ if no timeout.
    #
    # @return [Integer] amount of time passed
    def join(timeout = nil)
      time_passed = 0
      while @response.nil? && (timeout.nil? || time_passed < timeout)
        time_passed += (sleep JOIN_SLEEP_TIME)
      end
      time_passed
    end

    # Save into hash.
    def to_hash
      { type: "request", data: @data, id: @id, response: @response.to_i }
    end

    # Initialize new request from hash obtained with {Request#to_hash}.
    def self.from_hash(hash)
      Request.new(hash[:data], hash[:response], hash[:id])
    end
  end

  # Response to some request.
  class Response < Message
    # @return [Integer, Request] ID of initial request or request itself.
    attr_reader :request

    # Initialize new response.
    #
    # @param data [Hash]
    # @param request [Integer, Request]
    # @param id [Integer, nil]
    def initialize(data, request, id = nil)
      @request = request
      super(data, id)
    end

    # @return [String] human readable form.
    def to_s
      "#{super.to_s}; Initial request ID: #{@request.to_i}"
    end

    # Save into hash.
    def to_hash
      { type: "response", data: @data, id: @id, request: @request.to_i }
    end

    # Initialize new request from hash obtained with {Response#to_hash}.
    def self.from_hash(hash)
      Response.new(hash[:data], hash[:request], hash[:id])
    end
  end
end
