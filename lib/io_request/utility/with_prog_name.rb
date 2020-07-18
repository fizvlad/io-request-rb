# frozen_string_literal: true

module IORequest
  # Utility methods.
  module Utility
    # Adds special method to identify object in log files.
    module WithProgName
      # Identifies object and thread it runs in.
      def prog_name
        "#{self.class.name}##{object_id} in Thread##{Thread.current.object_id}"
      end
    end
  end
end
