# frozen_string_literal: true
require "json"
require "csv"

module Rack
  class SessionCounter
    class Error < StandardError; end

    def initialize(app, statsfile)
      @app = app
      @statsfile = statsfile
      @rate_limit_window = 30
      @rate_limit = 10
      @cooldown_duration = 15
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
      if login = get_login_from_session(env)
        log_authenticated_call(login)
      else
        log_anonymous_call
      end
    end

    def rate_limit_data(login:)
      call_count_active = 0
      last_call_time = nil
      end_time_range = Time.now
      start_time_range = end_time_range - @rate_limit_window
      time_remaining = @rate_limit_window
      if ::File.exist? @statsfile
        CSV.foreach(@statsfile) do |(time, call_login)|
          time = Time.at(time.to_i)
          if call_login == login && time > start_time_range
            call_count_active += 1
            last_call_time = [time, last_call_time].compact.max
            time_remaining = start_time_range - last_call_time
          end
        end
        { active_count: call_count_active, last_call: last_call_time, time_remaining: time_remaining }
      else
        { active_count: 0, last_call: end_time_range - @rate_limit_window, time_remaining: time_remaining }
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

    def get_login_from_session(env)
      if env["rack.session"]["loginstate"]
        Base64.decode64(env["rack.session"]["loginstate"])
      end
    end

    def rate_limit_exceeded?(env)
      if login = get_login_from_session(env)
        rate_limit_data = rate_limit_data(login: login)
        if rate_limit_data[:active_count] > @rate_limit
          time_offset = [rate_limit_data[:time_remaining], @cooldown_duration].max
          if rate_limit_data[:last_call_time] + time_offset  > Time.now
            return true
          end
        end
      end

      false
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
        if rate_limit_exceeded?(env)
          [429, {}, ["Rate Limit Exceeded"]]
        else
          log_call(env)
          @app.call(env)
        end
      end
    end
  end
end
