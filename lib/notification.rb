module Tracker
  require 'logger'

  def self.notify(message)
    SUPPORTED_NOTIFICATIONS.each do |m, klass|
      klass.new(message).notify
    end
  end

  def self.log(message)
    @logger ||= Logger.new(STDOUT)
  end

  class Notification
    attr_reader :message

    def initialize(message)
      @message = message
    end

    def notify
      @message
    end
  end

  class EmailNotification < Notification

    def initialize(message)
      super(message)
    end

    def notify
      email(super)
    end

    def email(message)
      subject, body = message.split(':', 2)
      begin
        Pony.mail(
          :to => recipients,
          :via => :smtp,
          :via_options => options,
          :subject => subject,
          :body => body
        )
      rescue => e
        puts "Failed to deliver notifications: #{e.message}"
      end
    end

    def options
      @options ||= YAML.load_file(File.join(File.dirname(__FILE__), '..', 'config', 'notification.yaml'))
      @options[:email] || {}
    end

    def recipients
      @yaml ||= YAML.load_file(File.join(File.dirname(__FILE__), '..', 'config', 'users.yaml'))
      @yaml[:users].keys
    end

  end

  SUPPORTED_NOTIFICATIONS = {
    :email => EmailNotification
  }

end
