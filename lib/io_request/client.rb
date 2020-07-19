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
    def initialize(authorizer: Authorizer.empty)
      @open = false
      @authorizer = authorizer

      @mutex_r = Mutex.new
      @mutex_w = Mutex.new

      @responses = {}
      @responses_access_mutex = Mutex.new
      @responses_access_cv = ConditionVariable.new
    end

    # Start new client connection.
    # @param r [IO] object to read from.
    # @param w [IO] object to write to.
    # @param rw [IO] read-write object (replaces `r` and `w` arguments).
    def open(read: nil, write: nil, read_write: nil)
      @io_r = read_write || read
      @io_w = read_write || write

      IORequest.logger.debug(prog_name) { 'Starting connection' }

      authorization
      @open = true
      @data_transition_thread = in_thread(name: 'connection') { data_transition_loop }
    end

    def open?
      @open
    end

    # Close connection.
    def close
      close_internal

      join_threads
    end

    # @yieldparam [Hash]
    # @yieldreturn [Hash]
    def on_request(&block)
      IORequest.logger.debug(prog_name) { 'Saved on_request block' }
      @on_request = block
    end
    alias respond on_request

    def on_close(&block)
      IORequest.logger.debug(prog_name) { 'Saved on_close block' }
      @on_close = block
    end

    # If callback block is provided, request will be sent asynchroniously.
    # @param data [Hash]
    def request(data = {}, &callback)
      message = Message.new(data, type: :request)

      if block_given?
        # Async execution of request
        in_thread(callback, name: 'requesting') do |cb|
          cb.call(send_request_and_wait_for_response(message).data)
        end
        nil
      else
        send_request_and_wait_for_response(message).data
      end
    end

    attr_reader :authorizer

    private

    def close_internal
      IORequest.logger.debug(prog_name) { 'Closing connection' }
      send_zero_size_request
      close_io
      @data_transition_thread = nil
      @open = false
      @on_close&.call if defined?(@on_close)
    end

    def close_io
      begin
        @io_r&.close
      rescue StandardError => e
        IORequest.logger.debug "Failed to close read IO: #{e}"
      end
      begin
        @io_w&.close
      rescue StandardError => e
        IORequest.logger.debug "Failed to close write IO: #{e}"
      end
      IORequest.logger.debug(prog_name) { 'Closed IO streams' }
    end

    def authorization
      auth_successful = @mutex_r.synchronize do
        @mutex_w.synchronize do
          IORequest.logger.debug(prog_name) { 'Authorizing new client' }
          @authorizer.authorize(@io_r, @io_w)
        end
      end
      unless auth_successful
        IORequest.logger.debug(prog_name) { 'Authorization failed' }
        raise 'Authorization failed'
      end

      IORequest.logger.debug(prog_name) { "New client authorized with data #{@authorizer.data}" }
    end

    def data_transition_loop
      IORequest.logger.debug(prog_name) { 'Starting data transition loop' }
      loop do
        data_transition_iteration
      rescue ZeroSizeMessageError
        IORequest.logger.debug(prog_name) { 'Connection was closed from the other side' }
        break
      rescue StandardError => e
        IORequest.logger.debug(prog_name) { "Data transition unknown error: #{e}" }
        break
      end
      close_internal
    end

    def data_transition_iteration
      message = @mutex_r.synchronize { Message.read_from(@io_r) }
      IORequest.logger.debug(prog_name) { "Received message: #{message}" }
      if message.request?
        in_thread(name: 'responding') { handle_request(message) }
      else
        handle_response(message)
      end
    end

    def handle_request(message)
      data = {}
      data = @on_request&.call(message.data) if defined?(@on_request)
      response = Message.new(data, type: :response, to: message.id)
      send_response(response)
    end

    def handle_response(message)
      @responses_access_mutex.synchronize do
        @responses[message.to.to_s] = message
        @responses_access_cv.broadcast
      end
    end

    def send_response(response)
      @mutex_w.synchronize do
        IORequest.logger.debug(prog_name) { "Sending response: #{response}" }
        response.write_to(@io_w)
      end
    end

    def send_zero_size_request
      @mutex_w.synchronize do
        IORequest.logger.debug(prog_name) { 'Sending zero size message' }
        @io_w.write([0].pack('S'))
      end
    rescue StandardError => e
      IORequest.logger.debug(prog_name) { "Failed to send zero-sized message(#{e})" }
    end

    def send_request_and_wait_for_response(request)
      @mutex_w.synchronize do
        IORequest.logger.debug(prog_name) { "Sending message: #{request}" }
        request.write_to(@io_w)
      end
      wait_for_response(request)
    end

    def wait_for_response(request)
      IORequest.logger.debug(prog_name) { "Waiting for response for #{request}" }
      @responses_access_mutex.synchronize do
        response = nil
        until response
          @responses_access_cv.wait(@responses_access_mutex)
          response = @responses[request.id.to_s]
        end
        IORequest.logger.debug(prog_name) { "Found response: #{response}" }
        response
      end
    end
  end
end
