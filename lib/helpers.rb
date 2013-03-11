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
        n "#{obj.patches.count} patches by #{obj.author}",
          erb(:'notifications/create_set', :locals => { :app => app, :obj => obj})
      end

      def send_update_status(app, obj)
        n "[#{obj.status.to_s.upcase}] #{obj.message[0..50]} by #{obj.updated_by}",
          erb(:'notifications/update_status', :locals => { :app => app, :obj => obj})
      end

    end

    module Application
      require 'digest/md5'

      def format_diff(diff)
        Diffy::HtmlFormatter.new(diff, {
          :include_plus_and_minus_in_html => true
        })
      end

      def gravatar(email)
        id = Digest::MD5::hexdigest(email.strip.downcase)
        'http://www.gravatar.com/avatar/' + id + '.jpg?s=64'
      end

      def format_build_state(state)
        case state
          when 'success' then '<span class="label label-success">PASSED</span>'
          when 'failure' then '<span class="label label-important">FAILED</span>'
          else ''
        end
      end

      def filter(collection)
        return collection if !params[:filter]
        return [] if !params[:filter_value]
        collection.all(:"#{params[:filter]}".like => params[:filter_value]+'%')
      end

      def format_counter(sets)
        not_pushed_count = sets.size - (sets.select { |s| s.nacked? }.size )
        '%i not pushed' % [ not_pushed_count]
      end

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
