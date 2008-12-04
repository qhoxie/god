module God
  module Conditions
    
    # Condition Symbol :simple_response
    # Type: Poll
    # 
    # Trigger based on the response data
    #
    # Paramaters
    #   Required
    #     +host+ is the hostname to connect [required]
    #     --one of code_is or code_is_not--
    #     +data_is+ trigger if the response code IS
    #     +data_is_not+ trigger if the response code IS NOT
    #     +data_contains+ trigger if the data CONTAINS
    #     +data_without+ trigger if the data DOES NOT CONTAIN
    #  Optional
    #     +port+ is the port to connect (default 80)
    #     +type+ either tcp or udp
    #     +times+ is the number of times after which to trigger (default 1)
    #             e.g. 3 (times in a row) or [3, 5] (three out of fives times)
    #     +timeout+ is the time to wait for a connection (default 60.seconds)
    #
    # Examples
    #
    # Trigger if the response code from www.example.com
    # is not "foo"  (or if the connection is refused or times out:
    #
    #   on.condition(:simple_response) do |c|
    #     c.host = 'www.example.com'
    #     c.data_is_not = "foo"
    #   end
    class SimpleResponse < PollCondition
      attr_accessor :data_is,
										:data_is_not,
										:data_contains,
										:data_without,
                    :times,        # e.g. 3 or [3, 5]
                    :host,         # e.g. www.example.com
                    :port,         # e.g. 8080
										:type,
                    :timeout      # e.g. 60.seconds
      
      def initialize
        super
				self.type = 'udp'
        self.times = [1, 1]
        self.timeout = 10.seconds
      end
      
      def prepare
        if self.times.kind_of?(Integer)
          self.times = [self.times, self.times]
        end
        
        @timeline = Timeline.new(self.times[1])
        @history = Timeline.new(self.times[1])
      end
      
      def reset
        @timeline.clear
        @history.clear
      end
      
      def valid?
        valid = true
	valid &= complain("Attribute 'type' must be either 'tcp' or 'udp'", self) if (self.type != 'tcp' && self.type != 'udp')
        valid &= complain("Attribute 'host' must be specified", self) if self.host.nil?
        valid &= complain("One (and only one) of attributes 'data_is', 'data_is_not', 'data_contains', and 'data_without' must be specified", self) if
          (self.data_is.nil? && self.data_contains.nil? && self.data_is_not.nil? && self.data_without.nil?) || (self.data_is && self.data_contains) || (self.data_is && self.data_is_not) || (self.data_is && self.data_without) || (self.data_contains && self.data_is_not) || (self.data_contains && self.data_without) || (self.data_is_not && self.data_without)
        valid
      end
      
      def test
        response = nil
        
				if self.type == 'tcp'
					sock = TCPSocket.new(self.host, self.port)
				else
					sock = UDPSocket.new()
					sock.connect(self.host, self.port)
				end

				response = sock.readlines.join(' ')


        if self.data_is && self.data_is.include?(response)
          pass(response)
        elsif self.data_contains && response =~ /#{self.data_contains}/
          pass(response)
        elsif self.data_is_not && self.data_is_not.include?(response)
          fail(response)
        elsif self.data_without && response =~ /#{self.data_without}/
          fail(response)
        else
          pass(response)
        end
      rescue Errno::ECONNREFUSED
        fail('Refused')
      rescue Errno::ECONNRESET
        fail('Reset')
      rescue EOFError
        fail('EOF')
      rescue Timeout::Error
        fail('Timeout')
      rescue Errno::ETIMEDOUT
        fail('Timedout')
      rescue Exception => failure
        fail(failure.class.name)
      end
      
      private
      
      def pass(data)
        @timeline << true
        self.info = "response nominal [#{data}]"
        false
      end
      
      def fail(data)
        @timeline << false
        self.info = "response abnormal [#{data}]"
        true
      end
      
    end
    
  end
end
