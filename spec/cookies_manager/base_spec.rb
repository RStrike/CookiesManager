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
        before { subject.write('my_key', @complex_data) }
        specify { unpack(cookies.signed['my_key']).should eql @complex_data }      
      end    
      context "when write nil value" do
        before { subject.write('my_key', nil) }
        specify { unpack(cookies.signed['my_key']).should be_nil}
      end
    end
    describe "write without packing data" do
      context "when write simple data" do
        before { subject.write('my_key', @simple_data, :skip_pack => true) }
        specify { cookies.signed['my_key'].should eql @simple_data }
      end
      context "when write nil value" do
        before { subject.write('my_key', nil, :skip_pack => true) }
        specify { cookies.signed['my_key'].should be_nil}
      end
    end
    describe "#write + set expiration date" do
      before { subject.write(@key = 'my_key', @complex_data, :expires => (@expiration_date = 2.hours.from_now)) }
      specify { cookies.instance_eval {@set_cookies['my_key'][:expires]}.should == @expiration_date }        
    end
    describe "#write with nil key" do
      before { subject.write(nil, @complex_data) }
      specify { unpack(cookies.signed[nil]).should eql @complex_data }
      specify { unpack(cookies.signed['']).should eql @complex_data }
    end
    describe "#write with empty string key" do
      before { subject.write('', @complex_data) }
      specify { unpack(cookies.signed[nil]).should eql @complex_data }
      specify { unpack(cookies.signed['']).should eql @complex_data }
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
        before { cookies.signed['my_key'] = {:value => @complex_data} }
        specify { subject.read('my_key', :skip_unpack => true).should eql @complex_data }
      end
      context "when reading a nil value" do
        before { cookies.signed['my_key'] = {:value => nil } }
        specify { subject.read('my_key').should be_nil }
      end
      context "when reading some data stored with a nil key" do
        before { cookies.signed[nil] = {:value => @complex_data} }
        specify { subject.read(nil, :skip_unpack => true).should eql @complex_data }
        specify { subject.read('', :skip_unpack => true).should eql @complex_data }
      end
      context "when reading some data stored with an empty string key" do
        before { cookies.signed[''] = {:value => @complex_data} }
        specify { subject.read(nil, :skip_unpack => true).should eql @complex_data }
        specify { subject.read('', :skip_unpack => true).should eql @complex_data }
      end
    end
    describe "#read some data previously stored through CookiesManager but later modified directly inside the cookies hash" do
      context "when read some simple data" do
        before do
          subject.write('my_key', @simple_data)
          cookies.signed['my_key'] = {:value => (@new_simple_data = "some new data")}
        end
        specify { subject.read('my_key', :skip_unpack => true).should eql @new_simple_data }
      end
      context "when reading some complex data" do
        before do
          subject.write('my_key', @complex_data)
          @new_complex_data = @complex_data.merge(:some_new_item => 'it modifies the data')
          cookies.signed['my_key'] = {:value => pack(@new_complex_data)}
        end
        specify { subject.read('my_key').should eql @new_complex_data }
        specify { unpack(subject.read('my_key', :skip_unpack => true)).should eql @new_complex_data } #if :skip_unpack option is set, we need to unpack the data manually
      end
    end
    describe "read with key symbol/string indifferent access (ex: :foo, 'foo')" do
      shared_examples_for "reading with indifferent access key" do
        specify { subject.read(:my_key).should eql @complex_data }  
        specify { subject.read('my_key').should eql @complex_data }
        specify { unpack(cookies.signed['my_key']).should eql @complex_data }
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
        before { cookies.signed['my_key'] = {:value => @complex_data} }
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
      before { cookies.signed['my_key'] = pack(@complex_data) }
      specify { subject.read('my_key', :unpack => true).should eql @complex_data }
      specify { subject.read('my_key', 'unpack' => true).should eql @complex_data }
    end
    describe "#write" do
      before do
        subject.write('key1', @simple_data, :skip_pack => true)
        subject.write('key2', @simple_data, 'skip_pack' => true)
      end
      specify { cookies.signed['key1'].should eql @simple_data }
      specify { cookies.signed['key2'].should eql @simple_data }
    end
    describe "#delete" do
      before { cookies.signed['my_key'] = pack(@complex_data) }
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
          cookies.signed['my_key'] = pack(@complex_data)
          subject.read('my_key').should eql @complex_data # this should store the data in the cache, thus sparing the need for future unpacking
          dont_allow(subject).unpack # this makes sure unpacking is never done (i.e. the cache is used)
        end
        it_should_behave_like 'when accessing the data'
      end 
      describe "#accessing some data that has been written through the CookiesManager" do
        before do
          subject.write('my_key', @complex_data) # this should store the data in the cache, thus sparing the need for future unpacking
          dont_allow(subject).unpack # this makes sure unpacking is never done (i.e. the cache is used)
        end 
        it_should_behave_like 'when accessing the data'
      end
    end
    describe "#cache out of sync" do
      before do
        subject.write('my_key', @original_data = ['my', 'original', 'array'])
        cookies.signed['my_key'] = pack(@complex_data) # this causes the cache to be out of sync, thus causing future reads to unmarshall the data from the cookies 
        mock.proxy(subject).unpack.with_any_args # this makes sure unpacking is invoked
      end
      it_should_behave_like 'when accessing the data'      
      describe "#automatic cache resynchronization on read" do
        before do 
          subject.read('my_key').should eql @complex_data # this causes unpacking, and cache resynchronization
          dont_allow(subject).unpack # this makes sure we don't unmarshall anymore at this point (i.e. the cache is now in sync and can be used)
        end 
        specify { subject.read('my_key').should eql @complex_data}
      end
    end  
  end
  
  describe "#cookies tampering" do
    describe "#when tampering a cookie value" do
      before do
        subject.write('my_key', @complex_data)
        cookies['my_key'] = 'some new value' # note that we intentionally don't call the method 'signed' on the cookies hash in order to tamper the cookies 
      end
      specify { subject.read('my_key').should be_nil}
    end
  end  
  
  
end

