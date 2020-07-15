# frozen_string_literal: true

require 'timeout'
require 'json'

module IORequest
  # Connection client.
  #
  # General scheme:
  #  Client 1                 Client 2
  #     |                        |
  #   (        Authorization       )  See `Authorizer` class. Error in authorization should close
  #     |                        |    connection
  #     |                        |
  #   [    Data transition loop    ]  Loop runs until someone sends 0 sized data. Then everyone
  #     |                        |    should close connection. Any R/W errors should also finish the
  #     |                        |    loop
  #     |                        |
  #     |-> uint(2 bytes)      ->|    Specifies size of following JSON string
  #     |-> Mesage as JSON     ->|    Message itself. It should contain its `type`, `id` and some
  #     |                        |    data hash
  #     |                        |
  #     |               (Message handling) See `Handler` class
  #     |                        |
  #     |<- uint(2 bytes)      <-|
  #     |<- Mesage as JSON     <-|
  class Client
    include Utility::WithProgName
    include Utility::MultiThread

    # Initialize new client.
    def initialize(authorizer: Authorizer::Empty)
      @authorizer = authorizer
    end

    # Start new client connection.
    # @param r [IO] object to read from.
    # @param w [IO] object to write to.
    # @param rw [IO] read-write object (replaces `r` and `w` arguments).
    def open(r: nil, w: nil, rw: nil)
      @io_r = rw ? rw : r
      @io_w = rw ? rw : w

      IORequest.logger.debug 'Opening connection in separate thread'
      in_thread(name: 'connection') { connection }
    end

    # Close connection.
    def close
      IORequest.logger.debug 'Closing connection'
      begin
        send_zero_size_message
      rescue StandardError => e
        IORequest.logger.debug 'Failed to send zero-sized message. Closing anyway'
      end
      close_io
      join_threads
    end

    # @yieldparam [Hash]
    # @yieldreturn [Hash]
    def respond(&block)
      @responder = block
    end

    # @param sync [Boolean]
    # @param data [Hash]
    def request(data, sync: true)
      # TODO
    end

    attr_reader :authorizer

    private

    def close_io
      @io_r&.close
      @io_w&.close
    end

    def connection
      authorization
      data_transition_loop
    end

    def authorization
      IORequest.logger.debug 'Authorizing new client'
      raise 'Authorization failed' unless @authorizer.authorize(@io_r, @io_w)
      IORequest.logger.debug "New client authorized with data #{@authorizer.data}"
    end

    def data_transition_loop
      loop do
        begin
          data_transition_iteration
        rescue StandardError => e
          IORequest.logger.warn "Data transition iteration failed:\n#{e.full_message}"
          break
        end
      end
    end

    def data_transition_iteration
      # TODO
    end

    def send_zero_size_message
      # TODO
    end
end
