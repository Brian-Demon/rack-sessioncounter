# frozen_string_literal: true

require "test_helper"

class Rack::SessionCounterTest < Minitest::Test
  include Rack::Test::Methods

  def get_call_count(type)
    get "/_auth/stats"
    data = JSON.parse(last_response.body)
    data["#{type}_calls"]
  end

  def teardown
    if File.exist? statsfile_path
      File.delete(statsfile_path)
    end
  end

  def statsfile_path
    File.expand_path(File.join(__FILE__, "..", "stats.txt"))
  end

  def app
    Rack::Builder.new do |builder|
      builder.use Rack::Session::Pool
      builder.use Rack::BasicLogin, "test"
      builder.use Rack::SessionCounter, File.expand_path(File.join(__FILE__, "..", "stats.txt"))
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
    get "/foo",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/bar",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/baz",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    assert_equal call_count+3, get_call_count("authenticated")
  end

  def test_authenticated_calls_persist_to_statsfile
    get "/foo",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/bar",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/baz",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    assert_equal 3, File.readlines(statsfile_path).length
  end

  def test_authenticated_calls_show_up_in_stats
    get "/foo",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/bar",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/baz",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/_auth/stats"
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 3, data["users"]["cadwallion"]
  end

  def test_most_active_users_returns_api_calls
    get "/foo",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/bar",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/baz",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/_auth/most_active"
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    users = data["users"]
    assert_equal 1, users.length
  end

  def test_most_active_users_returns_users_sorted_by_api_calls
    get "/foo",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/bar",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion") } }
    get "/baz",{}, { "rack.session" => { "loginstate" => Base64.encode64("demon") } }
    get "/_auth/most_active"
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    users = data["users"]
    assert_equal "cadwallion", users[0]["login"]
    assert_equal "demon", users[1]["login"]
  end

  def test_most_active_returns_only_five_users
    (1..10).each do |counter|
      counter.times do
        get "/foo",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion#{counter}") } }
      end
    end
    get "/_auth/most_active"
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal 5, data["users"].length
  end

  def test_most_active_returns_top_five_most_active_users
    (1..10).each do |counter|
      counter.times do
        get "/foo",{}, { "rack.session" => { "loginstate" => Base64.encode64("cadwallion#{counter}") } }
      end
    end
    get "/_auth/most_active"
    assert last_response.ok?
    data = JSON.parse(last_response.body)
    assert_equal({ "login" => "cadwallion10", "count" => 10 }, data["users"][0])
    assert_equal({ "login" => "cadwallion9", "count" => 9 }, data["users"][1])
    assert_equal({ "login" => "cadwallion8", "count" => 8 }, data["users"][2])
    assert_equal({ "login" => "cadwallion7", "count" => 7 }, data["users"][3])
    assert_equal({ "login" => "cadwallion6", "count" => 6 }, data["users"][4])
  end
end
