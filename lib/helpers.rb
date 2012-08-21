class DateTime
  def nice_format
    self.strftime("%m/%d/%Y %H:%M:%S")
  end
end

module Tracker
  module Helpers

    module Notification

      def n(subject, message)
        Tracker.notify("[TRACKER] #{subject}:#{erb(:notification, :locals => { :message => message})}")
      end

      def send_notification(type, app, obj)
        case type
          when :create_set then send_create_set_notification(app, obj)
          when :update_status then send_update_status(app, obj)
        end
      end

      def send_create_set_notification(app, obj)
        template = "The set #%i was successfully registered at http://%s/set/%i.\n"
        template += "\nPatches:\n\n"
        obj.patches.each do |p|
          template += "* [#{p.commit[-8, 8]}] #{p.message}\n"
          template += "   http://#{app.request.host}/patch/#{p.commit}\n\n"
        end
        template = template % [obj.id, app.request.host, obj.id]
        n "#{obj.patches.count} patches recorded by #{obj.author}", template
      end

      def send_update_status(app, obj)
        template = "The patch #{obj.commit[-8,8]} state changed to #{obj.status.to_s.upcase} "
        template += "by #{obj.updated_by}.\n"
        template += "\n\n* [#{obj.commit[-8,8]}] #{obj.message}\n"
        template += "    by #{obj.author}\n\n"
        template += "Notes:\n"
        template += obj.logs.last.message
        template += "\n\n"
        template += "View patch: http://#{app.request.host}/patch/#{obj.commit}\n"
        template += "Download patch: http://#{app.request.host}/patch/#{obj.commit}/download\n"
        n "Patch #{obj.commit[-8,8]} status changed to #{obj.status.to_s.upcase}", template
      end

    end

    module Application

      def format_status(value)
        case value
        when :new then "<span class='badge badge-info'>#{value.upcase}</span>"
        when :ack then "<span class='badge badge-success'>#{value.upcase}</span>"
        when :nack then "<span class='badge badge-important'>#{value.upcase}</span>"
        else "<span class='badge'>#{value.upcase}</span>"
        end
      end

      def format_set_status(set)
        return 'pushed' if set.pushed?
        return 'acked'  if set.acked?
        return 'nacked' if set.nacked?
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

      VALID_STATUS = [ :ack, :nack, :push, :note ]

      def check_valid_status!
        if params[:status].nil? || !VALID_STATUS.include?(params[:status].to_sym)
          halt 400, 'Requested status update not supported'
        end
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
          not_authorized! if !authorized?
          return
        end
        not_authorized!
      end

      def credentials
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        return {} if !@auth.provided?
        {
          :user => @auth.credentials[0],
          :password => @auth.credentials[1]
        }
      end

      def authorized?
        return false unless Authentication.users.has_key? credentials[:user]
        return false unless Authentication.users[credentials[:user]] == credentials[:password]
        true
      end

    end
  end
end
