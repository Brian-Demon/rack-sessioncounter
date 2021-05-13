# frozen_string_literal: true

require "test_helper"

class Rack::SessionCounterTest < Minitest::Test
  include Rack::Test::Methods

  def get_call_count(type)
    get "/_auth/stats"
    data = JSON.parse(last_response.body)
    data["#{type}_calls"]
  end

  def app
    Rack::Builder.new do |builder|
      builder.use Rack::Session::Pool
      builder.use Rack::BasicLogin, "test"
      builder.use Rack::SessionCounter
      builder.run lambda { |env| [200, {}, ["Welcome!"]]} 
    end.to_app
  end

  def test_get_authenticated_call_count
    get "/_auth/stats"

    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 0, data["authenticated_calls"]
  end

  def test_get_anonymous_call_count
    get "/_auth/stats"

    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 0, data["anonymous_calls"]
  end

  def test_unauthenticated_calls_increase_call_count
    call_count = get_call_count("anonymous")
    get "/foo"
    assert_equal call_count+1, get_call_count("anonymous")
  end

  def test_authenticated_calls_increase_call_count
    call_count = get_call_count("authenticated")
    get "/foo",{}, { "rack.session" => { "loginstate" => "cadwallion" } }
    get "/bar",{}, { "rack.session" => { "loginstate" => "cadwallion" } }
    get "/baz",{}, { "rack.session" => { "loginstate" => "cadwallion" } }
    assert_equal call_count+3, get_call_count("authenticated")
  end
end
