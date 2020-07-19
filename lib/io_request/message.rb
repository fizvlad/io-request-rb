# frozen_string_literal: true

module IORequest
  # Single message. Either request or response.
  class Message
    include Utility::WithID
    # Types of messages.
    TYPES = %i[request response].freeze

    # Create new message.
    # @param data [Hash]
    # @param type [Symbol] one of {TYPES} member.
    # @param id [Utility::ExtendedID, String, nil] only should be filled if
    #   message is received from outside.
    # @param to [Utility::ExtendedID, String, nil] if message is response, it
    #   should include integer of original request.
    def initialize(data, type: :request, id: nil, to: nil)
      @data = data
      @type = type
      @id = id.nil? ? extended_id : Utility::ExtendedID.from(id)
      @to = to.nil? ? nil : Utility::ExtendedID.from(to)

      check_data
    end

    # Check data correctness.
    def check_data
      raise '@data is not a hash' unless @data.is_a? Hash
      raise 'incorrect @type' unless TYPES.include? @type
      raise 'incorrect @id' unless @id.is_a? Utility::ExtendedID
      raise '@to not specified for response' if response? && @to.nil?
    end

    # @return [Hash]
    attr_reader :data

    # @return [Symbol]
    attr_reader :type

    # @return [Utility::ExtendedID]
    attr_reader :id

    # @return [Utility::ExtendedID]
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
      if request?
        "Request##{@id}: #{data}"
      else
        "Response##{@id}: #{data} to ##{@to}"
      end
    end

    # @return [String] binary data to be passed over IO.
    def to_binary
      json_string = JSON.generate({
                                    id: @id.to_s,
                                    type: @type.to_s,
                                    to: @to.to_s,
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
      size = io_r.read(2)&.unpack1('S') || 0
      raise ZeroSizeMessageError if size.zero?

      json_string = io_r.read(size).unpack1("a#{size}")
      msg = JSON.parse(json_string, symbolize_names: true)
      Message.new(msg[:data],
                  id: msg[:id],
                  type: msg[:type].to_sym,
                  to: msg[:to])
    end
  end
end
