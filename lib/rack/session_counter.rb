# frozen_string_literal: true
require "json"
require "csv"

module Rack
  class SessionCounter
    class Error < StandardError; end

    def initialize(app, statsfile)
      @app = app
      @statsfile = statsfile
      load_stats
    end

    def load_stats
      @stats = { authenticated_calls: 0, anonymous_calls: 0, users: {} }
      if ::File.exist? @statsfile
        CSV.foreach(@statsfile) do |row|
          time, user = row
          if user == ""
            @stats[:anonymous_calls] += 1
          else
            @stats[:authenticated_calls] += 1
            @stats[:users][user] ||= 0
            @stats[:users][user] += 1
          end
        end
      end
    end

    def log_call(env)
      if env["rack.session"]["loginstate"]
        login = Base64.decode64(env["rack.session"]["loginstate"])
        log_authenticated_call(login)
      else
        log_anonymous_call
      end
    end

    def log_authenticated_call(login)
      @stats[:authenticated_calls] += 1
      @stats[:users][login] ||= 0
      @stats[:users][login] += 1
      write_to_statsfile(login)
    end

    def log_anonymous_call
      @stats[:anonymous_calls] += 1
      write_to_statsfile("")
    end

    def write_to_statsfile(login)
      CSV.open(@statsfile, "a") do |csv|
        csv << [Time.now.to_i, login]
      end
    end

    def top_users(limit)
      sorted_users = @stats[:users].sort_by {|login, count| count }
      sorted_users.reverse.first(limit).map do |(login, count)|
        { login: login, count: count }
      end
    end

    def call(env)
      case env["PATH_INFO"]
      when "/_auth/stats"
        headers = { "Content-Type" => "application/json" }
        [200, headers, [JSON.generate(@stats)]] 
      when "/_auth/most_active"
        headers = { "Content-Type" => "application/json" }
        [200, headers, [JSON.generate({ users: top_users(5) })]] 
      else
        log_call(env)
        @app.call(env)
      end
    end
  end
end
