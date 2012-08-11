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

    get '/patches' do
      PatchSet.active.all(:order => [ :id.desc ]).to_json
    end

    get '/patches/:id' do
      Patch.status(params[:id]).to_json(:exclude => [:id])
    end

    post '/patches' do
      PatchSet.create_from_json(credentials[:user], request.env["rack.input"].read, env['HTTP_X_OBSOLETES']).to_json
    end

    post '/patches/:id/:status' do
      halt(400, 'Unsupported status') unless ['ack', 'nack', 'push'].include?params[:status]
      Patch.all(:commit => params[:id]).update(
        :status => params[:status].intern,
        :updated_by => credentials[:user]
      )
      status 200
    end

    get '/patches/:id/remove' do
      PatchSet.first(:id => params[:id]).destroy!
      redirect back
    end

    get '/patch/:id/:status' do
      halt(400, 'Unsupported status') unless ['ack', 'nack', 'push'].include?params[:status]
      Patch.first(:id => params[:id]).update(:status => params[:status].intern, :updated_by => credentials[:user])
      redirect back
    end

    get '/favico.ico' do
      halt 404, "No I don't have any favicon.ico"
    end

  end
end
