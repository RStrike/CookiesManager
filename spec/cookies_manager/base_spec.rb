require 'spec_helper'

# Useful macros for testing
module MacrosForCookiesManager
  def pack(data)
    Base64.encode64(ActiveSupport::Gzip.compress(Marshal.dump(data)))
  end
  
  def unpack(data)
    Marshal.load(ActiveSupport::Gzip.decompress(Base64.decode64(data)))
  end
end

include MacrosForCookiesManager
include Aquarium::Aspects

describe CookiesManager::Base do
  before(:all) do
    @complex_data = {:some_array => [1,2,3], :some_hash => {:a => 1, :b => 2}}
    @simple_data = "this is a simple string"
  end
  
  let(:cookies) { TestController.new.instance_eval { cookies } }
  subject { CookiesManager::Base.new(cookies) }  
  
  describe "#write" do
    describe "#write + pack data" do
      context "when write complex data" do
        before { @bytesize = subject.write('my_key', @complex_data) }
        specify { @bytesize.should == pack(@complex_data).bytesize }
        specify { unpack(cookies['my_key']).should eql @complex_data }      
      end    
      context "when write nil value" do
        before { @bytesize = subject.write('my_key', nil) }
        specify { @bytesize.should == pack(nil).bytesize }
        specify { unpack(cookies['my_key']).should be_nil}
      end
    end
    describe "write without packing data" do
      context "when write simple data" do
        before { @bytesize = subject.write('my_key', @simple_data, :skip_pack => true) }
        specify { @bytesize.should == @simple_data.bytesize }
        specify { cookies['my_key'].should eql @simple_data }
      end
      context "when write nil value" do
        before { @bytesize = subject.write('my_key', nil, :skip_pack => true) }
        specify { @bytesize.should == 0 }
        specify { cookies['my_key'].should be_nil}
      end
    end
    describe "#write + set expiration date" do
      before { subject.write(@key = 'my_key', @complex_data, :expires => (@expiration_date = 2.hours.from_now)) }
      specify { Time.parse(cookies.controller.response["Set-Cookie"].select { |cookie_str|  cookie_str =~ /\A#{@key}=/ }.last[/expires=(.*?)(;|\Z)/, 1]).to_i.should == @expiration_date.to_i } #parse the expiration date from the cookies string in the response header using some simple non-greedy regex and convert it to epochs to test the time equality. This conversion technique works only for timestamps between 1901-12-13 and 2038-01-19, but is acceptable for our tests.        
    end
    describe "#write with nil key" do
      before { subject.write(nil, @complex_data) }
      specify { unpack(cookies[nil]).should eql @complex_data }
      specify { unpack(cookies['']).should eql @complex_data }
    end
    describe "#write with empty string key" do
      before { subject.write('', @complex_data) }
      specify { unpack(cookies[nil]).should eql @complex_data }
      specify { unpack(cookies['']).should eql @complex_data }
    end
  end
  
  describe "#read" do
    describe "#read with unknown key" do
      specify { subject.read('unknown_key').should be_nil }
    end
    describe "#read some data previously stored through CookiesManager" do
      context "when reading non-nil data" do
        before { subject.write('my_key', @complex_data) }
        specify { subject.read('my_key').should eql @complex_data }
      end    
      context "when reading a nil value" do
        before { subject.write('my_key', nil) }
        specify { subject.read('my_key').should be_nil }
      end
      context "when reading some data stored with a nil key" do
        before { subject.write(nil, @complex_data) }
        specify { subject.read(nil).should eql @complex_data }
        specify { subject.read('').should eql @complex_data }
      end
    end
    describe "#read some data previously stored directly into the cookies hash" do
      context "when reading non-nil data" do
        before { cookies['my_key'] = {:value => @complex_data} }
        specify { subject.read('my_key', :skip_unpack => true).should eql @complex_data }
      end
      context "when reading a nil value" do
        before { cookies['my_key'] = {:value => nil } }
        specify { subject.read('my_key').should be_nil }
      end
      context "when reading some data stored with a nil key" do
        before { cookies[nil] = {:value => @complex_data} }
        specify { subject.read(nil, :skip_unpack => true).should eql @complex_data }
        specify { subject.read('', :skip_unpack => true).should eql @complex_data }
      end
      context "when reading some data stored with an empty string key" do
        before { cookies[''] = {:value => @complex_data} }
        specify { subject.read(nil, :skip_unpack => true).should eql @complex_data }
        specify { subject.read('', :skip_unpack => true).should eql @complex_data }
      end
    end
    describe "#read some data previously stored through CookiesManager but later modified directly inside the cookies hash" do
      context "when read some simple data" do
        before do
          subject.write('my_key', @simple_data)
          cookies['my_key'] = {:value => (@new_simple_data = "some new data")}
        end
        specify { subject.read('my_key', :skip_unpack => true).should eql @new_simple_data }
      end
      context "when reading some complex data" do
        before do
          subject.write('my_key', @complex_data)
          @new_complex_data = @complex_data.merge(:some_new_item => 'it modifies the data')
          cookies['my_key'] = {:value => pack(@new_complex_data)}
        end
        specify { subject.read('my_key').should eql @new_complex_data }
        specify { unpack(subject.read('my_key', :skip_unpack => true)).should eql @new_complex_data } #if :skip_unpack option is set, we need to unpack the data manually
      end
    end
    describe "read with key symbol/string indifferent access (ex: :foo, 'foo')" do
      shared_examples_for "reading with indifferent access key" do
        specify { subject.read(:my_key).should eql @complex_data }  
        specify { subject.read('my_key').should eql @complex_data }
        specify { unpack(cookies['my_key']).should eql @complex_data }
      end
      context "when data has been written with a key of type symbol" do
        before { subject.write(:my_key, @complex_data) }
        it_should_behave_like "reading with indifferent access key"
      end
      context "when data has been written with a key of type string" do
        before { subject.write('my_key', @complex_data) }
        it_should_behave_like "reading with indifferent access key"
      end
    end
  end
  
  describe "#delete" do
    describe "#delete existing data" do
      shared_examples_for "when deleting existing data" do
        before { @result = subject.delete('my_key', :skip_unpack => true) }
        specify { @result.should eql @complex_data }
        specify { subject.read('my_key').should be_nil }
      end
      context "when data has been previously stored through CookiesManager" do
        before { subject.write('my_key', @complex_data) }
        it_should_behave_like "when deleting existing data"
      end
      context "when data has been previously stored directly into the cookies hash" do
        before { cookies['my_key'] = {:value => @complex_data} }
        it_should_behave_like "when deleting existing data"
      end
    end
    describe "#delete non-existent data" do
      specify { subject.delete('unknown_key').should be_nil }
    end
    describe "#delete with key symbol/string indifferent access (ex: :foo, 'foo')" do
      shared_examples_for "when deleting with key of type symbol or string" do
        specify { @result.should eql @complex_data }
        specify { subject.read(:my_key).should be_nil }
        specify { subject.read('my_key').should be_nil }
      end
      shared_examples_for "when data has been written with a key of type symbol or string" do
        context "when deleting with key of type symbol" do
          before { @result = subject.delete(:my_key) }
          it_should_behave_like "when deleting with key of type symbol or string"
        end
        context "when deleting with key of type string" do
          before { @result = subject.delete('my_key') }
          it_should_behave_like "when deleting with key of type symbol or string"
        end
      end
      context "when data has been written with a key of type symbol" do        
        before { subject.write(:my_key, @complex_data) }
        it_should_behave_like "when data has been written with a key of type symbol or string"
      end      
      context "when data has been written with a key of type string" do
        before { subject.write('my_key',@complex_data) }
        it_should_behave_like "when data has been written with a key of type symbol or string"
      end
    end
  end
  
  describe "#symbol/string indifferent keys in options hash" do
    describe "#read" do
      before { cookies['my_key'] = pack(@complex_data) }
      specify { subject.read('my_key', :unpack => true).should eql @complex_data }
      specify { subject.read('my_key', 'unpack' => true).should eql @complex_data }
    end
    describe "#write" do
      before do
        subject.write('key1', @simple_data, :skip_pack => true)
        subject.write('key2', @simple_data, 'skip_pack' => true)
      end
      specify { cookies['key1'].should eql @simple_data }
      specify { cookies['key2'].should eql @simple_data }
    end
    describe "#delete" do
      before { cookies['my_key'] = pack(@complex_data) }
      specify { subject.delete('my_key', :unpack => true).should eql @complex_data }
      specify { subject.delete('my_key', 'unpack' => true).should eql @complex_data }
    end
  end
  
  describe "#cache management" do
    shared_examples_for 'when accessing the data' do
      context 'when reading' do
        specify { subject.read('my_key').should eql @complex_data }
      end
      context 'when deleting' do
        specify { subject.delete('my_key').should eql @complex_data }
      end
    end  
    describe "#cache in sync with the cookies" do
      describe "#accessing some data that has been read at least once by the CookiesManager" do
        before do
          cookies['my_key'] = pack(@complex_data)
          subject.read('my_key').should eql @complex_data # this should store the data in the cache, thus sparing the need for future unmarshalling
          dont_allow(Marshal).load # this makes sure unmarshalling is never done (i.e. the cache is used)
        end
        it_should_behave_like 'when accessing the data'
      end 
      describe "#accessing some data that has been written through the CookiesManager" do
        before do
          subject.write('my_key', @complex_data) # this should store the data in the cache, thus sparing the need for future unmarshalling
          dont_allow(Marshal).load # this makes sure unmarshalling is never done (i.e. the cache is used)
        end 
        it_should_behave_like 'when accessing the data'
      end
    end
    describe "#cache out of sync" do
      before do
        subject.write('my_key', @original_data = ['my', 'original', 'array'])
        cookies['my_key'] = pack(@complex_data) # this causes the cache to be out of sync, thus causing future reads to unmarshall the data from the cookies 
        mock.proxy(Marshal).load.with_any_args # this makes sure unmarshalling is invoked
      end
      it_should_behave_like 'when accessing the data'      
      describe "#automatic cache resynchronization on read" do
        before do 
          subject.read('my_key').should eql @complex_data # this causes unmarshalling, and cache resynchronization
          dont_allow(Marshal).load # this makes sure we don't unmarshall anymore at this point (i.e. the cache is now in sync and can be used)
        end 
        specify { subject.read('my_key').should eql @complex_data}
      end
    end  
  end
  
  describe "#multi-threading", :slow do
    def print_inside_critical_section(method_name)
      p "Inside the critical section, when calling cookies#{method_name}, the #{thread_name} thread pauses for #{sleep(2)} seconds, to make the other thread wait at the entrance of the critical section..."
    end  
    
    def print_wait_before_action(action)
      p "Before calling ##{action}, wait for #{sleep(1)} seconds to let the #{thread_name} thread lock the critical section..."
    end
    
    def run_thread
      Thread.new do
        Thread.current["name"] = thread_name
        yield
      end      
    end
    
    def build_aspect(method_name)
      Aspect.new :around, :calls_to => method_name, :on_objects => subject.cookies do |join_point, object, *args|          
        print_inside_critical_section(join_point.method_name) if Thread.current["name"] == thread_name
        join_point.proceed
      end      
    end
  
    before { subject.write('my_key', @original_data = 'original data') }
    after { @aspect.unadvise }
    
    describe "#a thread is reading with a key" do
      let(:thread_name) { :reader }
      before do
        @aspect = build_aspect('[]')
        @reader = run_thread { @result = subject.read('my_key') }
      end
      shared_examples_for 'when another thread wants to access the data with the same key while reading' do
        it "should wait until the reader finishes reading" do
          @reader.join
          @result.should eql @original_data
        end
      end
      context "when another thread wants to write some new data with the same key" do
        before do
          print_wait_before_action(:write)
          subject.write('my_key', @complex_data)
        end
        it_should_behave_like 'when another thread wants to access the data with the same key while reading'
      end
      context "when another thread wants to delete with the same key" do
        before do
          print_wait_before_action(:delete)
          subject.delete('my_key')
        end
        it_should_behave_like 'when another thread wants to access the data with the same key while reading'
      end      
    end
    describe "#a thread is writing with a key" do
      let(:thread_name) { :writer }
      before do
        @aspect = build_aspect('[]=')
        @writer = run_thread { subject.write('my_key', @complex_data) }
      end
      shared_examples_for 'when another thread wants to access the data with the same key while writing' do
        it 'should wait until the writer finishes writing' do
          @writer.join
          @result.should eql @complex_data
        end
      end
      context "when another thread wants to read with same key" do
        before do
          print_wait_before_action(:read)
          @result = subject.read('my_key')
        end
        it_should_behave_like 'when another thread wants to access the data with the same key while writing'
      end
      context "when another thread wants to delete with the same key" do
        before do
          print_wait_before_action(:delete)
          @result = subject.delete('my_key')
        end
        it_should_behave_like 'when another thread wants to access the data with the same key while writing'
      end      
    end
    describe "#a thread is deleting with a key" do
      let(:thread_name) { :deletor }
      before do
        @aspect = build_aspect(:delete)
        @deletor = run_thread { @delete_result = subject.delete('my_key') }
      end
      shared_examples_for 'when another thread wants to access the data with the same key while deleting' do
        it 'should wait until the deletor finishes deleting' do
          @deletor.join
          @delete_result.should eql @original_data
        end        
      end
      context "when another thread wants to read with the same key" do
        before do
          print_wait_before_action(:read)
          @read_result = subject.read('my_key')
        end
        it_should_behave_like 'when another thread wants to access the data with the same key while deleting'
        specify { @read_result.should be_nil }
      end
      context "when another thread wants to write with the same key" do
        before do
          print_wait_before_action(:write)
          subject.write('my_key', @complex_data)
        end
        it_should_behave_like 'when another thread wants to access the data with the same key while deleting'
      end      
    end
  end
  
end

