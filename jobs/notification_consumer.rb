require_relative '../lib/notification'

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
