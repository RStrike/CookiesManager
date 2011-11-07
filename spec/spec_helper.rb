require 'rubygems'
require 'bundler/setup'
require 'action_controller'
Bundler.require(:default)

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run :focus => true
  config.filter_run_excluding :slow => ENV["SKIP_SLOW"].present?
  config.run_all_when_everything_filtered = true
  config.mock_with :rr
end

 # A test controller with a cookies hash (this works in rails 2.3.14 but needs to be adapted for versions of rails >= 3.x.x)
class TestController < ActionController::Base

  def request 
    @request ||= ActionController::Request.new('test')
  end
  
  def response
    @response ||= ActionController::Response.new
  end  
  
  def initialize
    self.cookies = ActionController::CookieJar.new(self)
  end
  
  protected
  
  attr_accessor :cookies
       
end
