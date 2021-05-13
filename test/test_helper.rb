# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "rack/session_counter"
require "rack/basic_login"
require "rack/test"
require "json"

require "minitest/autorun"