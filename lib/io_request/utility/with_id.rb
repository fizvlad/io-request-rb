# frozen_string_literal: true

module IORequest
  # Utility methods.
  module Utility
    # Extended Id of object
    class ExtendedID
      include Comparable

      # Create new Id based on PID, thread ID and object ID.
      def initialize(pid = nil, tid = nil, oid = nil)
        @pid = pid || Process.pid
        @tid = tid || Thread.current.object_id
        @oid = oid || object_id
      end

      # @return [Integer] process ID.
      attr_reader :pid

      # @return [Integer] thread ID.
      attr_reader :tid

      # @return [Integer] object ID.
      attr_reader :oid

      # @return [String]
      def to_s
        "#{@pid}##{@tid}##{@oid}"
      end

      # Comparison operator.
      def <=>(other)
        if @pid == other.pid && @tid == other.tid
          @oid <=> other.oid
        elsif @pid == other.pid && @tid != other.tid
          @tid <=> tid
        else
          @pid <=> other.pid
        end
      end

      def self.from(obj)
        case obj
        when ExtendedID then new(obj.pid, obj.tid, obj.oid)
        when String then new(*obj.split('#').map(&:to_i))
        else
          raise 'unknown type'
        end
      end
    end
    # Adds special method to return object ID.
    module WithID
      # Identifies object in thread and process.
      def __with_id__extended_id
        @__with_id__extended_id ||= ExtendedID.new
      end
      alias extended_id __with_id__extended_id
    end
  end
end
