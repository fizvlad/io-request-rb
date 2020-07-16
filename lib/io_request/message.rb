# frozen_string_literal: true

module IORequest
  # Single message. Either request or response.
  class Message
    # Types of messages.
    TYPES = %i[request response].freeze

    # Create new message.
    # @param data [Hash]
    # @param type [Symbol] one of {TYPES} member.
    # @param id [Integer, nil] only should be filled if message is received from outside.
    # @param to [Integer, nil] if message is response, it should include integer of original request.
    def initialize(data, type: :request, id: nil, to: nil)
      @data = data
      @type = type
      @id = object_id
      @to = to
    end

    # @return [Hash]
    attr_reader :data

    # @return [Symbol]
    attr_reader :type

    # @return [Integer]
    attr_reader :id

    # @return [Integer]
    attr_reader :to

    # @return [Boolean]
    def request?
      @type == :request
    end

    # @return [Boolean]
    def response?
      @type == :response
    end

    # @return [String]
    def to_s
      "#{type}##{@id}: #{data}"
    end

    # @return [String] binary data to be passed over IO.
    def to_binary
      json_string = JSON.generate({
                                    id: @id,
                                    type: @type.to_s,
                                    to: @to,
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
      Message.new(msg[:data], id: msg[:id].to_i, type: msg[:type].to_sym)
    end
  end
end
