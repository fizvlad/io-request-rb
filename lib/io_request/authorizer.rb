# frozen_string_literal: true

module IORequest
  # Class to authorize client connection.
  class Authorizer
    # @yieldparam io_r [IO] input stream.
    # @yieldparam io_w [IO] output stream.
    # @yieldreturn [Object, nil] if `nil` is returned, authorization will be
    #   considered as failed one. Otherwise data will be saved into `data`.
    def initialize(&block)
      @block = block
      @data = nil
    end

    # @return [Object] literally any non-nil data from block.
    attr_reader :data

    # @return [Boolean] authorization status.
    def authorize(io_r, io_w)
      @data = nil
      @data = @block.call(io_r, io_w)
      @data.nil?
    rescue StandardError
      false
    end
  end

  # No authorization.
  Authorizer::Empty = Authorizer.new { |_io_r, _io_w| true }
end
