# frozen_string_literal: true

module IORequest
  # Utility methods.
  module Utility
    # Adds some methods to spawn new threads and join them.
    # @note This module creates instance variables with prefix +@__multi_thread__+.
    module MultiThread
      private

      # @return [Array<Thread>] array of running threads.
      def __multi_thread__threads
        @__multi_thread__threads ||= []
      end
      alias running_threads __multi_thread__threads

      # @return [Mutex] threads manipulations mutex.
      def __multi_thread__mutex
        @__multi_thread__mutex ||= Mutex.new
      end

      # Runs block with provided arguments forwarded as arguments in separate thread.
      # All the inline args will be passed to block.
      # @param thread_name [String] thread name.
      # @return [Thread]
      def in_thread(*args, name: nil)
        # Synchronizing addition/deletion of new threads. That's important
        __multi_thread__mutex.synchronize do
          new_thread = Thread.new(*args) do |*in_args|
            yield(*in_args)
          ensure
            __multi_thread__remove_current_thread
          end
          __multi_thread__threads << new_thread
          new_thread.name = name if name
          new_thread
        end
      end

      # Removes current thread from thread list.
      def __multi_thread__remove_current_thread
        __multi_thread__mutex.synchronize do
          __multi_thread__threads.delete(Thread.current)
        end
      end

      # For each running thread.
      def each_thread(&block)
        __multi_thread__threads.each(&block)
      end

      # Kills each thread.
      def kill_threads
        each_thread(&:kill)
      end

      # Joins each thread.
      def join_threads
        each_thread(&:join)
      end
    end
  end
end
