# frozen_string_literal: true

module IORequest
  # Single message. Either request or response.
  class Message
    # Message creation mutex
    @@mutex = Mutex.new # rubocop:disable Style/ClassVars
    # Messages counter
    @@counter = 0 # rubocop:disable Style/ClassVars

    # Types of messages.
    TYPES = %i[request response].freeze

    # Create new message.
    # @param data [Hash]
    # @param id [Integer, nil] only should be filled if message is received from outside.
    # @param type [Symbol] one of {TYPES} member.
    def initialize(data, id: nil, type: :request)
      @@mutex.synchronize do
        @@counter += 1 # rubocop:disable Style/ClassVars

        @data = data
        @id = @@counter
        @type = type
      end
    end

    # @return [Hash]
    attr_reader :data

    # @return [Integer]
    attr_reader :id

    # @return [Symbol]
    attr_reader :type

    # @return [String] binary data to be passed over IO.
    def to_binary
      json_string = JSON.generate({
                                    id: @id,
                                    type: @type.to_s,
                                    data: @data
                                  })
      [json_string.size, json_string].pack("Sa#{json_string.size}")
    end

    # @param io_w [:write]
    def write_to(io_w)
      io_w.write(to_binary)
    end

    # @param io_r [:read]
    # @return [Message]
    def self.read_from(io_r)
      size = io_r.read(2).unpack1('S')
      json_string = io_r.read(size).unpack1("a#{size}")
      msg = JSON.parse(json_string, symbolize_names: true)
      Message.new(msg[:data], id: msg[:id], type: msg[:type])
    end
  end
end
