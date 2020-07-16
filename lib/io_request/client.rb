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
    def open(read: nil, write: nil, read_write: nil)
      @io_r = read_write || read
      @io_w = read_write || write

      IORequest.logger.debug 'Opening connection in separate thread'
      in_thread(name: 'connection') { connection }
    end

    # Close connection.
    def close
      IORequest.logger.debug 'Closing connection'
      begin
        send_zero_size_request
      rescue StandardError
        IORequest.logger.debug 'Failed to send zero-sized message. Closing anyway'
      end
      close_io
      join_threads
    end

    # @yieldparam [Hash]
    # @yieldreturn [Hash]
    def respond(&block)
      IORequest.logger.debug 'Saved responder block'
      @responder = block
    end

    # If callback block is provided, request will be sent asynchroniously.
    # @param data [Hash]
    def request(data = {}, &_callback)
      message = Message.new(data, type: :request)
      IORequest.logger.debug "Sending request #{message}"

      if block_given?
        in_thread(name: "req#{message.id}") { yield send_request_and_wait_for_response(message) }
        nil
      else
        send_request_and_wait_for_response(message)
      end
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
        data_transition_iteration
      rescue StandardError => e
        IORequest.logger.warn "Data transition iteration failed:\n#{e.full_message}"
        break
      end
    end

    def data_transition_iteration
      # TODO: read message size
      # TODO: read JSON
      # TODO: if it is request pass data to responder, get reply and send it
      # TODO: if it is response, get data and pass it to awaiting requester
    end

    def send_zero_size_request
      # TODO: send zero
      # TODO: close connection
    end

    def send_request_and_wait_for_response(request)
      request.write_to(@io_w)
    end
  end
end
