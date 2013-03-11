require_relative '../lib/notification'
require 'pony'

module Jobs
  class NotificationConsumer < TorqueBox::Messaging::MessageProcessor

    def on_message(body)
      ::Tracker::EmailNotification.new(body.to_s).notify
    end

    def on_error(e)
      warn "Error delivering mail: #{e.message}"
    end

  end
end
