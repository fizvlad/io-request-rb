module IORequest
  # Utility methods.
  module Utility
    # Adds special method to identify object in log files.
    module WithProgName
      ##
      # Identifies object and thread it runs in.
      def prog_name
        self_class = self.class
        "#{self_class.name}##{object_id} in Thread##{Thread.current.object_id}"
      end
    end

    # Adds some methods to spawn new threads and join them.
    #
    # @note This module creates instance variables with prefix +@_MultiThread_+.
    module MultiThread
      private

      # @return [Array<Thread>] array of running threads
      def running_threads
        @_MultiThread_threads ||= []
      end

      # Runs block with provided arguments forwarded as arguments in separate thread.
      #
      # @return [Thread]
      def in_thread(*args, &block)
        @_MultiThread_threads ||= []
        @_MultiThread_mutex ||= Mutex.new
        # Synchronizing addition/deletion of new threads. That's important
        @_MultiThread_mutex.synchronize do
          new_thread = Thread.new(*args) do |*in_args|
            begin
              block.call(*in_args)
            ensure
              @_MultiThread_mutex.synchronize do
                @_MultiThread_threads.delete(Thread.current)
              end
            end
          end
          @_MultiThread_threads << new_thread
          new_thread
        end        
      end

      # For each running thread.
      def each_thread(&block)
        @_MultiThread_threads ||= []
        
        @_MultiThread_threads.each(&block)
      end

      # Kills each thread.
      def kill_threads
        each_thread(&:kill)
        each_thread(&:join)
      end

      # Joins each thread.
      def join_threads
        each_thread(&:join)
      end
    end
  end
end

# Extending Hash class.
class Hash
  # Use this on JSON objects to turn all the +String+ keys of hash to symbols.
  #
  # @param depth [Integer] maximum amount of hashes to handle. This is just a
  #   simple way to protect from infinite loop.
  #
  # @return [self]
  def symbolize_keys!(depth = 1000)
    queue = [self]
    count = 0
    while h = queue.shift
      h.transform_keys! { |key| key.is_a?(String) ? key.to_sym : key }
      h.each_value { |v| queue.push(v) if v.is_a?(Hash) }
      count += 1
      break if count >= depth
    end
    self
  end
end

