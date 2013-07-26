# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'net/https'
require 'json'

# Container module for classes relating to Squash.

module Squash

  # Class that handles communicating with the Squash API.
  #
  # By default, transmission is done with `Net::HTTP`. If this is unpalatable to
  # you, reimplement {#http_post}.

  class Uploader

    # Default configuration options. See {#initialize}.
    DEFAULT_CONFIGURATION = {
        :open_timeout      => 15,
        :read_timeout      => 15,
        :skip_verification => false,
        :success           => [Net::HTTPSuccess]
    }

    # @return [String] The host name and scheme of the Squash server (e.g.,
    #   "https://squash.mycompany.com").
    attr_accessor :host
    # @return [Hash<Symbol, Object>] Additional options for uploading.
    attr_accessor :options

    # Creates a new Squash uploader that will communicate with a given host.
    #
    # @param [String] host The host name and scheme of the Squash server (e.g.,
    #   "https://squash.mycompany.com").
    # @param [Hash] options Additional options.
    # @option options [Fixnum] :open_timeout (15) The number of seconds to wait
    #   when opening a connection to the Squash server.
    # @option options [Fixnum] :read_timeout (15) The number of seconds to wait
    #   when waiting for data from the Squash server.
    # @option options [true, false] :skip_verification (false) If `true`, SSL
    #   peer verification will not be performed.
    # @option options [Array<Class, Fixnum>] :success ([Net::HTTPSuccess]) A
    #   list of subclasses of `Net::HTTPResponse` or response codes that are
    #   considered successful and will not raise an exception.

    def initialize(host, options={})
      @host    = host
      @options = DEFAULT_CONFIGURATION.merge(options)
    end

    # Transmits information to Squash.
    #
    # @param [String] path The path portion of the URL, with leading slash.
    # @param [Hash] data Data to JSON-serialize and place in the request body.

    def transmit(path, data)
      http_post (host + path),
                {'Content-Type' => 'application/json'},
                [data.to_json]
    end

    protected

    # Override this method to use your favorite HTTP library. This method receives
    # an array of bodies. It is intended that each element of the array be
    # transmitted as a separate POST request, _not_ that the bodies be
    # concatenated and sent as one request.
    #
    # A response of code found in the `:success` option is considered successful.
    #
    # @param [String] url The URL to POST to.
    # @param [Hash<String, String>] headers The request headers.
    # @param [Array<String>] bodies The bodies of each request to POST.
    # @raise [StandardError] If a response other than 2xx or 422 is returned.

    def http_post(url, headers, bodies)
      uri               = URI.parse(url)
      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = (uri.scheme == 'https')
      http.open_timeout = options[:open_timeout]
      http.read_timeout = options[:read_timeout]
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if options[:skip_verification]

      http.start do |session|
        bodies.each do |body|
          request = Net::HTTP::Post.new(uri.request_uri)
          headers.each { |k, v| request.add_field k, v }
          request.body = body
          response     = session.request(request)

          if options[:success].none? { |cl|
            if cl.kind_of?(Class)
              response.kind_of?(cl)
            elsif cl.kind_of?(Fixnum) || cl.kind_of?(String)
              response.code.to_i == cl.to_i
            else
              raise ArgumentError, "Unknown :success value #{cl}"
            end
          }
            raise "Unexpected response from Squash host: #{response.code}"
          end
        end
      end
    end
  end
end
