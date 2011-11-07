require 'spec_helper'

describe CookiesManager::ControllerAdditions do
  let(:controller) { TestController.new }
  context "when calling the class method :load_cookies_manager on the controller class" do
    before do
      mock(TestController).helper_method(:cookies_manager) # makes sure the :cookies_manager method is declared as a helper (to make it available to the views, for example)
      mock(TestController).before_filter { |block| block.call(controller) } # makes sure a before_filter is set AND runs the filter block with our controller as an argument
      TestController.load_cookies_manager # the class method we want to test
    end
    it "should create a :cookies_manager instance method" do
      controller.method(:cookies_manager).should_not be_nil
    end
    it "the :cookies_manager method should return a CookiesManager object" do
      controller.cookies_manager.is_a? CookiesManager
    end
    it "consecutives calls to the :cookies_manager method should return the SAME CookiesManager object" do
      controller.cookies_manager.should equal controller.cookies_manager #strict equality required 
    end
    it "the CookiesManager object should be based on the native controller's cookies hash" do
      controller.cookies_manager.cookies.should equal controller.instance_eval { cookies } #strict equality required
    end
  end
end
