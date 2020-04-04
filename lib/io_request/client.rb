require "base64"
require "timeout"
require "json"

module IORequest
  # Connection client.
  class Client
    include Utility::WithProgName
    include Utility::MultiThread

    # Initialize new client over IO.
    #
    # @option options [:gets] read IO to read from.
    # @option options [:puts] write IO to write to.
    def initialize(read: nil, write: nil)
      @io_r = read
      @io_w = write

      @mutex = Mutex.new
      @responders = [] # Array of pairs [Subhash, Block]
      @out_requests = {} # Request => Proc

      @receive_thread = Thread.new { receive_loop }
      IORequest.debug("New IORequest client initialized", prog_name)
    end

    # Send request.
    #
    # Optional block can be provided. It will be called when response received.
    #
    # @option options [Hash] data data to send.
    # @option options [Boolean] sync whether to join request after sending.
    # @option options [Integer, Float] timeout timeout for {Request#join}.
    #
    # @yieldparam request [Response] response for request.
    #
    # @return [Request]
    def request(data: {}, sync: false, timeout: nil, &block)
      req = Request.new(data)
      @out_requests[req] = block
      IORequest.debug("Sending request ##{req.id}", prog_name)
      send(req.to_hash)
      req.join(timeout) if sync
      req
    end

    # Setup block for answering incoming requests.
    #
    # @param subdata [Hash] provided block will be called only if received data
    #   includes this hash.
    #
    # @yieldparam request [Request] incoming request.
    # @yieldreturn [Hash] data to be sent in response.
    #
    # @return [nil]
    def respond(subdata = {}, &block)
      @responders << [subdata, block]
      nil
    end

    private

    # Starts receiving loop and freezes thread.
    def receive_loop
      loop do
        h = receive(nil)
        break if h.nil?
        case h[:type]
          when "request"
            handle_in_request(Request.from_hash h)
          when "response"
            handle_in_response(Response.from_hash h)
          else
            IORequest.warn("Unknown message type: #{h[:type].inspect}", prog_name)
        end
      end
      IORequest.debug("Receive loop exited", prog_name)
    end
    # Handle incoming request.
    def handle_in_request(req)
      IORequest.debug("Handling request ##{req.id}", prog_name)
      in_thread(name: "request_handler") do
        responder = find_responder(req)
        data = nil
        data = begin
          if responder
            responder.call(req)
          else
            IORequest.warn "Responder not found!"
            nil
          end
        rescue Exception => e
          IORequest.warn "Provided block raised exception:\n#{e.full_message}", prog_name
          nil
        end
        data ||= {}
        res = Response.new(data, req)
        send(res.to_hash)
      end
      nil
    end
    # Handle incoming response.
    def handle_in_response(res)
      req_id = res.request.to_i
      req = @out_requests.keys.find { |r| r.id == req_id }
      unless req
        IORequest.warn("Request ##{req_id} not found", prog_name)
        return
      end
      IORequest.debug("Request ##{req_id} response received", prog_name)
      req.response = res
      # If block is not provided it's totally ok
      block = @out_requests.delete(req)
      if block
        in_thread(name: "response_handle") do
          begin
            block.call(res)
          rescue Exception => e
            IORequest.warn("Provided block raised exception:\n#{e.full_message}", prog_name)
          end
        end
      end
    end

    # find responder for provided request.
    def find_responder(req)
      result = nil
      @responders.each do |subdata, block|
        if req.data.contains? subdata
          result = block
          break
        end
      end

      result
    end

    # Send data.
    #
    # @param [Hash]
    def send(data)
      IORequest.debug("Sending hash: #{data.inspect}", prog_name)
      send_raw(encode(data_to_string data))
    end

    # Receive data.
    #
    # @param timeout [Integer, Float, nil] timeout size or +nil+ if no timeout required.
    #
    # @return [Hash, nil] hash or +nil+ if timed out or IO was closed.
    def receive(timeout)
      str = Timeout::timeout(timeout) do
        receive_raw
      end
      return nil if str.nil?
      string_to_data(decode(str))
    rescue Timeout::Error
      nil
    rescue IOError
      nil
    rescue Exception => e
      IORequest.warn "Exception of #{e.class} encountered while trying to receive message. Suggesting IO was closed. Full trace: #{e.full_message}", prog_name
      nil
    end

    # Send string.
    def send_raw(str)
      @io_w.puts str
    end
    # Receive string.
    def receive_raw
      @io_r.gets&.chomp
    end

    # Encode string
    def encode(str)
      Base64::strict_encode64 str
    end
    # Decode string
    def decode(str)
      Base64::strict_decode64 str
    end

    # Turn data into string
    def data_to_string(data)
      JSON.generate(data)
    end
    # Turn string into data
    def string_to_data(str)
      JSON.parse(str).symbolize_keys!
    end
  end
end
