require 'bundler/setup'
require 'action_controller'
require 'active_support/all'
Bundler.require(:default)

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run :focus => true
  config.filter_run_excluding :slow => ENV["SKIP_SLOW"].present?
  config.run_all_when_everything_filtered = true
  config.mock_with :rr
end

class TestController < ActionController::Base

  def initialize(*args)
    super(*args)
    self.cookies = ActionDispatch::Cookies::CookieJar.new('b57121a9239fe9e55d46c534c7af7218')
  end
  
  protected
  
  attr_accessor :cookies
       
end
