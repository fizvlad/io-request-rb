# frozen_string_literal: true

require_relative '../../io_request'

require 'socket'
require 'openssl'

module IORequest
  # Connection via SSL sockets
  module SSLSockets
    # SSL socket server.
    class Server
      include Utility::MultiThread

      # Initalize new server.
      # @param port [Integer] port of server.
      # @param authorizer [Authorizer]
      # @param certificate [String]
      # @param key [String]
      def initialize(
        port: 8000,
        authorizer: Authorizer.empty,
        certificate: nil,
        key: nil,
        &requests_handler
      )
        @port = port
        @authorizer = authorizer
        @requests_handler = requests_handler

        initialize_ssl_context(certificate, key)
      end

      # @return [Array<IORequest::Client>]
      attr_reader :clients

      # Start server.
      def start
        @clients = []

        @server = TCPServer.new(@port)

        @accept_thread = in_thread(name: 'accept_thr') { accept_loop }
      end

      # Fully stop server.
      def stop
        @clients.each(&:close)
        @clients = []

        @server.close
        @server = nil

        @accept_thread&.kill
        @accept_thread = nil
      end

      private

      def initialize_ssl_context(certificate, key)
        @ctx = OpenSSL::SSL::SSLContext.new
        @ctx.cert = OpenSSL::X509::Certificate.new certificate
        @ctx.key = OpenSSL::PKey::RSA.new key
        @ctx.ssl_version = :TLSv1_2
      end

      def accept_loop
        while (socket = @server.accept)
          handle_socket(socket)
        end
      rescue
        stop
      end

      def handle_socket(socket)
        ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, @ctx)
        ssl_socket.accept

        client = IORequest::Client.new authorizer: @authorizer
        begin
          client.open read_write: ssl_socket
          client.respond(&@requests_handler)
          @clients << client
        rescue StandardError
          IORequest.debug "Failed to open client: #{e}"
          ssl_socket.close
        end
      rescue StandardError => e
        IORequest.warn "Unknown error while handling sockets: #{e}"
      end
    end

    # SSL socket client.
    class Client
      # Initialize new client.
      # @param authorizer [Authorizer]
      # @param certificate [String]
      # @param key [String]
      def initialize(
        authorizer: Authorizer.empty,
        certificate: nil,
        key: nil,
        &requests_handler
      )
        @authorizer = authorizer
        @requests_handler = requests_handler

        initialize_ssl_context(certificate, key)
      end

      # Connect to server.
      # @param host [String] host of server.
      # @param port [Integer] port of server.
      def connect(host = 'localhost', port = 8000)
        socket = TCPSocket.new(host, port)

        ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, @ctx)
        ssl_socket.sync_close = true
        ssl_socket.connect

        @client = IORequest::Client.new authorizer: @authorizer
        begin
          @client.open read_write: ssl_socket
          @client.respond(&@requests_handler)
        rescue StandardError
          IORequest.debug "Failed to open client: #{e}"
          ssl_socket.close
          @client = nil
        end
      end

      # Closes connection to server.
      def disconnect
        return unless defined?(@client) && !@client.nil?

        @client.close
        @client = nil
      end

      # Wrapper over {IORequest::Client#request}
      def request(*args, **options, &block)
        @client.request(*args, **options, &block)
      end

      private

      def initialize_ssl_context(certificate, key)
        @ctx = OpenSSL::SSL::SSLContext.new
        @ctx.cert = OpenSSL::X509::Certificate.new certificate
        @ctx.key = OpenSSL::PKey::RSA.new key
        @ctx.ssl_version = :TLSv1_2
      end
    end
  end
end
