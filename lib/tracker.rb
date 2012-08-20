module Tracker

  class App < Sinatra::Base

    include Tracker::Models

    helpers Tracker::Helpers::Authentication
    helpers Tracker::Helpers::Application

    use Rack::CommonLogger

    set :views, File.join(File.dirname(__FILE__), '..', 'views')
    set :public_folder, File.join(File.dirname(__FILE__), '..', 'public')

    enable :method_override
    enable :sessions
    disable :show_exceptions

    register Sinatra::Partial

    get '/login' do
      must_authenticate!
      redirect '/'
    end

    get '/' do
      @sets = PatchSet.active.all(:order => [ :id.desc ])
      haml :index
    end

    get '/patch/:id', :provides => :html do
      @patch = Patch.first(:commit => params[:id], :order => [ :id.desc ])
      throw(:halt, [404, 'Patch %s not found. <a href="/">Back.</a>']) if @patch.nil?
      haml :patch
    end

    get '/patch/:id', :provides => :json do
      Patch.status(params[:id]).to_json(:exclude => [:id, :body])
    end

    get '/patch/:id/download' do
      content_type 'text/plain'
      attachment "#{params[:id]}.patch"
      [200, {}, Patch.first(:commit => params[:id], :order => [ :id.desc]).body]
    end

    get '/set', :provides => :json do
      PatchSet.active.all(:order => [ :id.desc ]).to_json
    end

    get '/set/:id', :provides => :html do
      @set = PatchSet.active.first(:id => params[:id])
      throw(:halt, [404, 'Set %s not found. <a href="/">Back.</a>']) if @set.nil?
      haml :set
    end

    get '/set/:id', :provides => :json do
      PatchSet.first(params[:id]).to_json(:methods => [:patches])
    end

    post '/set' do
      must_authenticate!
      PatchSet.create_from_json(credentials[:user], request.env["rack.input"].read, env['HTTP_X_OBSOLETES']).to_json
    end

    post '/patch/:id/:status' do
      must_authenticate!
      check_valid_status!
      Patch.first(:commit => params[:id], :order => [ :id.desc]).update_status!(
        params[:status],
        credentials[:user],
        params[:message]
      )
    end

    get '/set/:id/destroy' do
      must_authenticate!
      PatchSet.first(:id => params[:id]).obsolete!
      redirect '/'
    end

    get '/patch/:id/:status' do
      must_authenticate!
      params[:status] = params[:action] if !params[:action].nil?
      check_valid_status!
      Patch.first(:id => params[:id]).update_status!(
        params[:action] || params[:status],
        credentials[:user],
        params[:message]
      )
      redirect back
    end

    put '/patch/:commit/body' do
      must_authenticate!
      patch = Patch.status(params[:commit])
      throw(:halt, [404, 'Patch %s not found. <a href="/">Back.</a>']) if patch.nil?
      patch.attach!(request.env["rack.input"].read)
      status 201
    end

    get '/favico.ico' do
      halt 404, "No I don't have any favicon.ico"
    end

  end
end
