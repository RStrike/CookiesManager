module CookiesManager

  # This module provides a CookiesManager facility for your controllers.
  # It is automatically extended by all controllers.
  module ControllerAdditions
    
    # Sets up a before filter that creates a new CookiesManager into an instance variable,   
    # which is made available to all views through the +cookies_manager+ helper method.
    #
    # You can call this method on your controller class as follows:
    #
    #   class YourController < ApplicationController
    #     load_cookies_manager
    #   
    def load_cookies_manager
      self.before_filter do |controller|
        # defines a CookiesManager instance variable, based on the cookies hash
        controller.instance_variable_set(:@_cookies_manager, CookiesManager::Base.new(controller.cookies))
        # wraps the instance variable in a the +cookies_manager+ method
        define_method :cookies_manager, proc { controller.instance_variable_get(:@_cookies_manager) }
        # makes the +cookies_manager+ method available to all views as a helper method
        helper_method :cookies_manager
      end
    end
  end
end

# Automatically add all ControllerAdditions methods to controller classes as class methods 
ActionController::Base.extend CookiesManager::ControllerAdditions
