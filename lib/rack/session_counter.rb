# frozen_string_literal: true

module Rack
  class SessionCounter
    class Error < StandardError; end

    def initialize(app)
      @app = app
      @stats = { 
        authenticated_calls: 0, 
        anonymous_calls: 0
      }
    end

    def log_call(env)
      if env["rack.session"]["loginstate"]
        login = Base64.decode64(env["rack.session"]["loginstate"])
        @stats[:authenticated_calls] += 1
      else
        @stats[:anonymous_calls] += 1
      end
    end

    def call(env)
      if env["PATH_INFO"] == "/_auth/stats"
        headers = { "Content-Type" => "application/json" }
        [200, headers, [JSON.generate(@stats)]] 
      else
        log_call(env)
        @app.call(env)
      end
    end
  end
end
