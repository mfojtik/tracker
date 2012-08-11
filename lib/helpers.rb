module Tracker
  module Helpers

    module Application

      def format_status(value)
        case value
        when :new then "<span class='badge badge-info'>#{value.upcase}</span>"
        when :ack then "<span class='badge badge-success'>#{value.upcase}</span>"
        when :nack then "<span class='badge badge-important'>#{value.upcase}</span>"
        when :push then  "<span class='badge'>#{value.upcase}</span>"
        end
      end

      def format_patch_numbers(patches)
        result = '%d patches' % patches.size
        if patches.all(:status => :push).size == patches.size
          result += ', all pushed!'
        else
          result += ', %d acked' % patches.all(:status => :ack).size
          result += ', %d nacked' % patches.all(:status => :nack).size
        end
        result
      end

    end

    module Authentication

      def self.users
        @users ||= YAML.load_file(File.join(File.dirname(__FILE__), '..', 'config', 'users.yaml'))[:users]
      end

      def not_authorized!
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end

      def must_authenticate!
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        if @auth.provided? && @auth.basic? && @auth.credentials
          not_authorized! unless Authentication.users.has_key? credentials[:user]
          not_authorized! unless Authentication.users[credentials[:user]] == credentials[:password]
          return
        end
        not_authorized!
      end

      def credentials
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        {
          :user => @auth.credentials[0],
          :password => @auth.credentials[1]
        }
      end

    end
  end
end
