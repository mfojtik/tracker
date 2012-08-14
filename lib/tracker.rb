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

    before do
      must_authenticate!
    end

    get '/' do
      @sets = PatchSet.active.all(:order => [ :id.desc ])
      haml :index
    end

    get '/patches/:id', :provides => :html do
      @patch = Patch.first(:commit => params[:id], :order => [ :id.desc ])
      haml :patch
    end

    get '/patches', :provides => :json do
      PatchSet.active.all(:order => [ :id.desc ]).to_json
    end

    get '/patches/:id', :provides => :json do
      Patch.status(params[:id]).to_json(:exclude => [:id])
    end

    post '/patches' do
      PatchSet.create_from_json(credentials[:user], request.env["rack.input"].read, env['HTTP_X_OBSOLETES']).to_json
    end

    post '/patches/:id/:status' do
      check_valid_status!
      Patch.first(:commit => params[:id], :order => [ :id.desc]).update_status!(
        params[:status],
        credentials[:user],
        params[:message]
      )
    end

    get '/patches/:id/remove' do
      PatchSet.first(:id => params[:id]).destroy!
      redirect back
    end

    get '/patch/:id/:status' do
      params[:status] = params[:action] if !params[:action].nil?
      check_valid_status!
      Patch.first(:id => params[:id]).update_status!(
        params[:action] || params[:status],
        credentials[:user],
        params[:message]
      )
      redirect back
    end

    get '/favico.ico' do
      halt 404, "No I don't have any favicon.ico"
    end

  end
end
