module CookiesManager

  # This module provides a CookiesManager facility for your controllers.
  # It is automatically extended by all controllers.
  module ControllerAdditions
    
    module ClassMethods
      # Sets up a before filter that creates a new CookiesManager into an instance variable,   
      # which is made available to all views through the +cookies_manager+ helper method.
      #
      # You can call this method on your controller class as follows:
      #
      #   class YourController < ApplicationController
      #     load_cookies_manager
      #   
      def load_cookies_manager
        before_filter :build_cookies_manager
      end
    end
    
    # Builds a cookies manager as a controller instance variable, made available to all views
    def build_cookies_manager
      # defines a CookiesManager instance variable, based on the cookies hash
      @_cookies_manager = CookiesManager::Base.new(cookies)
      # wraps the instance variable in the +cookies_manager+ instance method
      define_singleton_method :cookies_manager, proc { @_cookies_manager }
      # makes the +cookies_manager+ method available to all views as a helper method
      self.class.helper_method :cookies_manager
    end
    
    def self.included(base)
      base.extend ClassMethods
    end
        
  end
end

# Automatically add all ControllerAdditions methods to controllers 
if defined? ActionController
  ActionController::Base.class_eval do
    include CookiesManager::ControllerAdditions
  end
end
