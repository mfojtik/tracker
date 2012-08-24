module Tracker

  class App < Sinatra::Base

    include Tracker::Models
    include Rack::Utils

    alias_method :h, :escape_html

    helpers Tracker::Helpers::Authentication
    helpers Tracker::Helpers::Application
    helpers Tracker::Helpers::Notification

    use Rack::CommonLogger

    set :views, File.join(File.dirname(__FILE__), '..', 'views')
    set :public_folder, File.join(File.dirname(__FILE__), '..', 'public')

    disable :show_exceptions

    register Sinatra::Partial

    get '/login' do
      must_authenticate!
      redirect '/'
    end

    get '/' do
      sets = filter PatchSet.active
      @counter = format_counter(sets)
      @sets = sets.page(params[:page] || 1, :per_page => 10)
      haml :index
    end

    get '/patch/:id', :provides => :html do
      @patch = Patch.active(params[:id])
      throw(:halt, [404, 'Patch %s not found. <a href="/">Back.</a>' % params[:id]]) if @patch.nil?
      haml :patch
    end

    get '/patch/:id', :provides => :json do
      patch = Patch.active(params[:id])
      throw(:halt, [404, 'Patch %s not found. <a href="/">Back.</a>']) if patch.nil?
      patch.to_json(:exclude => [:id, :body])
    end

    get '/patch/:id/download' do
      content_type 'text/plain'
      attachment "#{params[:id]}.patch"
      patch = Patch.active(params[:id])
      throw(:halt, [404, 'Patch %s not found. <a href="/">Back.</a>']) if patch.nil?
      [200, {}, patch.body]
    end

    get '/set', :provides => :json do
      sets = filter PatchSet.active
      sets.to_json(:methods => [ :first_patch_message, :num_of_patches ])
    end

    get '/set/:id', :provides => :html do
      @set = PatchSet.active.first(:id => params[:id])
      throw(:halt, [404, 'Set %s not found. <a href="/">Back.</a>']) if @set.nil?
      haml :set
    end

    get '/set/:id', :provides => :json do
      set = PatchSet.first(:id => params[:id])
      throw(:halt, [404, 'Set %s not found. <a href="/">Back.</a>']) if set.nil?
      {
        :id => set.id,
        :patches => set.patches.all(:order => [ :id.desc ]).map { |p| p.commit }
      }.to_json
    end

    post '/set', :provides => :json do
      must_authenticate!
      set = PatchSet.create_from_json(
        credentials[:user],
        request.env["rack.input"].read,
        env['HTTP_X_OBSOLETES']
      )
      send_notification(:create_set, self, set)
      set.to_json
    end

    post '/patch/:commit/body' do
      must_authenticate!
      patch = Patch.active(params[:commit])
      throw(:halt, [404, 'Patch %s not found. <a href="/">Back.</a>']) if patch.nil?
      patch.attach!(params['diff'][:tempfile].read)
      status 201
    end

    post '/patch/:id/:status', :provides => :json do
      must_authenticate!
      check_valid_status!
      patch = Patch.active(params[:id])
      throw(:halt, [404, 'Patch %s not found. <a href="/">Back.</a>']) if patch.nil?
      patch = patch.update_status!(params[:status], credentials[:user], params[:message])
      send_notification :update_status, self, patch.reload
      patch.to_json
    end

    get '/set/:id/destroy', :provides => :html do
      must_authenticate!
      PatchSet.first(:id => params[:id]).obsolete!
      redirect '/'
    end

    post '/set/:id/:status', :provides => :json do
      must_authenticate!
      check_valid_status!
      set = PatchSet.first(:id => params[:id])
      throw(:halt, [404, 'Patch %s not found. <a href="/">Back.</a>']) if set.nil?
      set.patches.each do |p|
        patch = p.update_status!(params[:status], credentials[:user], params[:message])
        send_notification :update_status, self, patch
      end
      halt 204
    end

    get '/patch/:id/:status', :provides => :html do
      must_authenticate!
      params[:status] = params[:action] if !params[:action].nil?
      check_valid_status!
      patch = Patch.first(:id => params[:id])
      throw(:halt, [404, 'Patch %s not found. <a href="/">Back.</a>']) if patch.nil?
      patch = patch.update_status!(
        params[:action] || params[:status],
        credentials[:user],
        params[:message]
      )
      send_notification :update_status, self, patch
      redirect back
    end

    get '/favico.ico' do
      halt 404, "No I don't have any favicon.ico"
    end

  end
end
