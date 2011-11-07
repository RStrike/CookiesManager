require 'aquarium'

module CookiesManager
  # The base class of CookiesManager 
  class Base
    include Aquarium::DSL # AOP Filters are defined at the end of the class
    
    attr_accessor :cookies # The cookies hash to be based on
    
    # Constructs a new CookiesManager instance based on a cookies hash
    #
    # The CookiesManager instance is created automatically when you call the +load_cookies_manager+ class method
    # on your controller, so you don't need to instantiate it directly.
    #
    # === Example:
    # Inside your controller, call the +load_cookies_manager+ method:
    #
    #   class YourController < ActionController::Base
    #     load_cookies_manager
    #
    def initialize(input_cookies)
      self.cookies = input_cookies
    end

    # Reads the data object corresponding to the key.
    #
    # Reads from the cache instance variable, or from the cookies if the cache is not in sync with the cookies.
    # Cache desynchronization can occur when the cookies hash is modified directly.
    # The cache is automatically re-synchronized if out of sync.
    #
    # If option +:unpack+ is set to true, data will be successively base64-decoded, unzipped, and unmarshalled. This option is used only when the data
    # is retrieved from the cookies hash (i.e. the cache is not in sync with the cookies).
    #
    # === Example: 
    #    data = cookies_manager.read('my_key') # reads the data associated with the key 'my_key'
    #
    # @param [String or Symbol] key a unique key corresponding to the data to read
    # @option opts [Boolean] :unpack if true, successively base64-decode, unzip, and unmarshall the data. Default is false.
    # @return [Object] the data associated with the key 
    #
    def read(key, opts = {})
      result = nil
      getMutex(key).synchronize do
        result = read_from_cache_or_cookies(key, opts)  
      end      
      return result
    end
    
    # Writes the data object and associates it with the key.
    #
    # Data is stored in both the cookies and the cache.
    # 
    # By default, before being stored in the cookies, data is marshalled, zipped, and base64-encoded. Although this feature is recommended, you can disable it by passing the option +:skip_pack+ if you consider your data can be stored as is in the cookies (ex: US-ASCII string).
    #
    # === Examples:
    #    
    #    array_data = {:some_item => "an item", :some_array => ['This', 'is', 'an', 'array']}
    #    #store the data in the cookies as a base64-encoded string, for one hour:
    #    len_bytes1 = cookies_manager.write('key_for_my_array', data, :expires => 1.hour.from_now)
    #
    #    simple_data = "a simple string"
    #    # store the data as in in the cookies, and keep it as long as the browser remains open:
    #    len_bytes2 = cookies_manager.write('key_for_my_simple_data', simple_data, :skip_pack => true)
    #
    # @param [String or Symbol] key a unique key to associate the data with
    # @param [Hash] opts a customizable set of options, built on top of the native set of options supported when {http://api.rubyonrails.org/v2.3.8/classes/ActionController/Cookies.html setting cookies}
    # @option opts [Boolean] :skip_pack if true, DO NOT marshall, zip, nor base64-encode the data. Default is false.     
    # @option opts [String] :path the path for which this cookie applies. Defaults to the root of the application.
    # @option opts [String] :domain the domain for which this cookie applies.
    # @option opts [String] :expires the time at which this cookie expires, as a Time object.
    # @option opts [String] :secure whether this cookie is a only transmitted to HTTPS servers. Default is +false+.
    # @option opts [String] :httponly whether this cookie is accessible via scripting or only HTTP. Defaults to +false+.
    # @return [Integer] the number of bytes written in the cookies
    #
    def write(key, data, opts = {})
      unpacked_data = data
      data = pack(data) unless opts[:skip_pack]
      result = nil
      getMutex(key).synchronize do
        cache[key] ||= {}
        result = cookies[key] = {:value => data}.merge(opts) # store the packed data in the cookies hash
        cache[key][:unpacked_data] = unpacked_data # store the unpacked data in the cache for fast read in the read method
        cache[key][:packed_data] = data # store the packed data in the cache for fast change diff in the read method
      end
      return result[:value].try(:bytesize) || 0
    end
        
    # Deletes the data corresponding to the key.
    #
    # Removes the data from both the cookies and the cache, and return it.
    # The returned value is read from the cache if this is in sync with the cookies. Otherwise, the data is read from the cookies, in which case it is successively
    # base64-decoded, unzipped, and unmarshalled if option +:unpack+ is set to true.
    #
    # === Example:
    #     data = cookies_manager.delete('my_key')  # deletes the data associated with the key 'my_key'
    #
    # @param [String or Symbol] key a unique key corresponding to the data to delete   
    # @option opts (see #read)
    # @return (see #read) 
    #
    def delete(key, opts = {})
      result = nil
      getMutex(key).synchronize do
        result = read_from_cache_or_cookies(key, opts)
        cookies.delete(key)
        cache.delete(key)
      end
      return result
    end
    
    #=====#
    private
    #=====#
    
    def cache
      @cache ||= {} # The cookies cache
    end
    
    def mutexes
      @mutexes ||= {} # A hash composed of {key;mutex} pairs where each mutex is used to synchronize operations on the data associated with the key
    end
    
    def global_mutex
      @global_mutex ||= Mutex.new # A global mutex to synchronize accesses to the mutexes hash
    end
    
    # reads from the cache if in sync. Otherwise, reads from the cookies and resynchronizes the cache for the given key
    def read_from_cache_or_cookies(key, opts)
      result = nil
      data_from_cookies = cookies[key]
      cache[key] ||= {}
      if cache[key][:packed_data] == data_from_cookies # checks whether cache is in sync with cookies
        result = cache[key][:unpacked_data] # reads from cache
      else # cache not in sync
        result = opts[:unpack] ? unpack(data_from_cookies) : data_from_cookies # read from cookies
        # updates the cache
        cache[key][:packed_data] = data_from_cookies
        cache[key][:unpacked] = result
      end
      return result
    end
    
    def getMutex(key)
      global_mutex.synchronize do # synchronize accesses to the mutexes hash
        mutexes[key] ||= Mutex.new
      end      
    end
    
    def pack(data)
      Base64.encode64(ActiveSupport::Gzip.compress(Marshal.dump(data)))
    end

    def unpack(data)
      Marshal.load(ActiveSupport::Gzip.decompress(Base64.decode64(data)))
    end    
    
    #=================#
    #== AOP Filters ==#
    #=================#
    
    # Since Aquarium sets the arities of observered methods to -1, we need to save the methods arities in a hash declared as a class variable
    self.instance_methods(false).each { |method| (@method_arities ||= {})[method.to_sym] = instance_method(method).arity }
    
    around :methods => [:read, :write, :delete] do |join_point, object, *args|
      key = (args[0] = args[0].to_s) # we should stick with string keys since the cookies hash does not support indifferent access (i.e. :foo and "foo" are different keys), although this has changed in rails 3.1
      opts = args[last_arg_index(join_point.method_name)] # retrieve the options arg (last argument)
      opts.symbolize_keys! if opts.is_a?(Hash)
      join_point.proceed(*args)
    end

    # Returns the index of the last arg in the method signature
    def self.last_arg_index(method_name)
      instance_eval { @method_arities[method_name] }.abs - 1
    end
    
  end
    
end
