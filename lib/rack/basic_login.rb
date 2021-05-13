require "base64"

module Rack
  class BasicLogin
    def initialize(app, token)
      @app = app
      @token = token
    end

    def extract_credentials_from_header(header)
      if match = header.match(/Basic (.*)/)
        return Base64.decode64(match[1]).split(":")
      else
        []
      end
    end

    def login(env)
      if env["HTTP_AUTHORIZATION"]
        user, password = extract_credentials_from_header(env["HTTP_AUTHORIZATION"])

        if password == @token
          env["rack.session"]["loginstate"] = Base64.encode64(user)
          @app.call(env)
        else
          [403, {"Content-Type" => "text/plain"}, ["Forbidden"]]
        end
      else
        [422, {"Content-Type" => "text/plain"}, ["Invalid Request"]]
      end
    end

    def call(env)
      if env["REQUEST_METHOD"] == "POST"
        case env["PATH_INFO"]
        when "/login"
          return login(env)
        when "/logout"
          return logout(req)
        end
      end

      @app.call(env)
    end
  end
end