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
      def clients
        @clients_data.keys
      end

      # @param client [IORequest::Client]
      # @return [Hash, nil] you are free to store anything you want in hash.
      #   Only field you will find in it is `auth` with authenticator data.
      def data(client)
        @clients_data[client]
      end

      # Start server.
      def start
        @clients_data = {}

        @server = TCPServer.new(@port)

        @accept_thread = in_thread(name: 'accept_thr') { accept_loop }
      end

      # Fully stop server.
      def stop
        clients.each(&:close)
        @clients_data.clear

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
      rescue StandardError
        stop
      end

      def handle_socket(socket)
        ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, @ctx)
        ssl_socket.accept

        handle_client(ssl_socket, IORequest::Client.new(authorizer: @authorizer))
      rescue StandardError => e
        IORequest.logger.warn "Unknown error while handling sockets: #{e}"
      end

      def handle_client(ssl_socket, client)
        auth_data = client.open read_write: ssl_socket
        client.on_request { |data| @requests_handler.call(data, client) }
        @clients_data[client] = { auth: auth_data }
        client.on_close do
          @clients_data.select! { |c, _d| c.open? }
        end
      rescue StandardError => e
        IORequest.logger.debug "Failed to open client: #{e}"
        ssl_socket.close
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

        @client = nil

        initialize_ssl_context(certificate, key)
      end

      def connected?
        !@client.nil?
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
          @client.on_request(&@requests_handler)
        rescue StandardError
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
