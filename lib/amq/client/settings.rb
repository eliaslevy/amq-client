# encoding: utf-8

require "amq/protocol/client" # TODO: "amq/protocol/constants"
require "uri"

module AMQ
  module Client
    # @see AMQ::Client::Settings.configure
    module Settings
      # @private
      AMQP_PORTS = {"amqp" => 5672, "amqps" => 5671}.freeze

      # @private
      AMQPS = "amqps".freeze

      # Default connection settings used by AMQ clients
      #
      # @see AMQ::Client::Settings.configure
      def self.default
        @default ||= {
          # server
          :host  => "127.0.0.1",
          :port  => AMQ::Protocol::DEFAULT_PORT,

          # login
          :user  => "guest",
          :pass  => "guest",
          :vhost => "/",

          # connection timeout
          :timeout => nil,

          # logging
          :logging => false,

          # ssl
          :ssl => false,

          # broker
          # if you want to load broker-specific extensions
          :broker => nil,

          :frame_max => 131072
        }
      end

      CLIENT_PROPERTIES = {
        :platform     => ::RUBY_DESCRIPTION,
        :product      => "AMQ Client",
        :information  => "http://github.com/ruby-amqp/amq-client",
        :version      => AMQ::Client::VERSION
      }
      
      def self.client_properties
        @client_properties ||= CLIENT_PROPERTIES
      end


      # Merges given configuration parameters with defaults and returns
      # the result.
      #
      # @param [Hash] Configuration parameters to use.
      #
      # @option settings [String] :host ("127.0.0.1") Hostname AMQ broker runs on.
      # @option settings [String] :port (5672) Port AMQ broker listens on.
      # @option settings [String] :vhost ("/") Virtual host to use.
      # @option settings [String] :user ("guest") Username to use for authentication.
      # @option settings [String] :pass ("guest") Password to use for authentication.
      # @option settings [String] :ssl (false) Should be use TLS (SSL) for connection?
      # @option settings [String] :timeout (nil) Connection timeout.
      # @option settings [String] :logging (false) Turns logging on or off.
      # @option settings [String] :broker (nil) Broker name (use if you intend to use broker-specific features).
      # @option settings [Fixnum] :frame_max (131072) Maximum frame size to use. If broker cannot support frames this large, broker's maximum value will be used instead.
      #
      # @return [Hash] Merged configuration parameters.
      def self.configure(settings = nil)
        case settings
        when Hash then
          if username = settings.delete(:username)
            settings[:user] ||= username
          end

          if password = settings.delete(:password)
            settings[:pass] ||= password
          end


          self.default.merge(settings)
        when String then
          settings = self.parse_amqp_url(settings)
          self.default.merge(settings)
        when NilClass then
          self.default
        end
      end

      # Parses AMQP connection URI and returns its components as a hash.
      #
      # h2. vhost naming schemes
      #
      # It is convenient to be able to specify the AMQP connection
      # parameters as a URI string, and various "amqp" URI schemes
      # exist.  Unfortunately, there is no standard for these URIs, so
      # while the schemes share the basic idea, they differ in some
      # details.  This implementation aims to encourage URIs that work
      # as widely as possible.
      #
      # The URI scheme should be "amqp", or "amqps" if SSL is required.
      #
      # The host, port, username and password are represented in the
      # authority component of the URI in the same way as in http URIs.
      #
      # The vhost is obtained from the first segment of the path, with the
      # leading slash removed.  The path should contain only a single
      # segment (i.e, the only slash in it should be the leading one).
      # If the vhost is to include slashes or other reserved URI
      # characters, these should be percent-escaped.
      #
      # @example How vhost is parsed
      #
      #   AMQ::Client::Settings.parse_amqp_url("amqp://dev.rabbitmq.com")            # => vhost is nil, so default (/) will be used
      #   AMQ::Client::Settings.parse_amqp_url("amqp://dev.rabbitmq.com/")           # => vhost is an empty string
      #   AMQ::Client::Settings.parse_amqp_url("amqp://dev.rabbitmq.com/%2Fvault")   # => vhost is /vault
      #   AMQ::Client::Settings.parse_amqp_url("amqp://dev.rabbitmq.com/production") # => vhost is production
      #   AMQ::Client::Settings.parse_amqp_url("amqp://dev.rabbitmq.com/a.b.c")      # => vhost is a.b.c
      #   AMQ::Client::Settings.parse_amqp_url("amqp://dev.rabbitmq.com/foo/bar")    # => ArgumentError
      #
      #
      # @param [String] connection_string AMQP connection URI, à la JDBC connection string. For example: amqp://bus.megacorp.internal:5877.
      # @return [Hash] Connection parameters (:username, :password, :vhost, :host, :port, :ssl)
      #
      # @raise [ArgumentError] When connection URI schema is not amqp or amqps, or the path contains multiple segments
      #
      # @see http://bit.ly/ks8MXK Connecting to The Broker documentation guide
      # @api public
      def self.parse_amqp_url(connection_string)
        uri = URI.parse(connection_string)
        raise ArgumentError.new("Connection URI must use amqp or amqps schema (example: amqp://bus.megacorp.internal:5766), learn more at http://bit.ly/ks8MXK") unless %w{amqp amqps}.include?(uri.scheme)

        opts = {}

        opts[:scheme] = uri.scheme
        opts[:user]   = URI.unescape(uri.user) if uri.user
        opts[:pass]   = URI.unescape(uri.password) if uri.password
        opts[:host]   = uri.host if uri.host
        opts[:port]   = uri.port || AMQ::Client::Settings::AMQP_PORTS[uri.scheme]
        opts[:ssl]    = uri.scheme == AMQ::Client::Settings::AMQPS
        if uri.path =~ %r{^/(.*)}
          raise ArgumentError.new("#{uri} has multiple-segment path; please percent-encode any slashes in the vhost name (e.g. /production => %2Fproduction). Learn more at http://bit.ly/amqp-gem-and-connection-uris") if $1.index('/')
          opts[:vhost] = URI.unescape($1)
        end

        opts
      end
    end
  end
end
