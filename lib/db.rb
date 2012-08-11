module Tracker
  module Models

    def self.included(base)
      DataMapper::Logger.new($stdout, :debug)
      if ENV['RACK_ENV'] == 'production'
        DataMapper.setup(:default,
                         :adapter  => 'mongo',
                         :host => '',
                         :username => 'admin',
                         :password => '',
                         :database => ''
                        )
      else
        DataMapper.setup(:default, "sqlite://#{File.join(File.dirname(__FILE__), '..')}/tracker.db")
      end
      DataMapper.finalize
      DataMapper.auto_upgrade!
    end

    class Patch
      include DataMapper::Resource

      property :id, Serial
      property :commit, String
      property :author, String
      property :message, Text
      property :commited_at, DateTime
      property :status, Enum[ :new, :ack, :nack, :push ], :default => :new
      property :updated_by, String
      property :revision, Integer

      property :created_at, DateTime
      property :updated_at, DateTime

      belongs_to :patch_set

      def self.status(commit_id)
        all(:commit => commit_id).select { |p| p.patch_set.revision > 0 }.map { |p| (p.revision = p.patch_set.revision) && p }.first
      end
    end

    class PatchSet
      include DataMapper::Resource

      property :id, Serial
      property :author, String
      property :revision, Integer, :default => 1
      property :created_at, DateTime

      has n, :patches

      def pushed?
        patches.all(:status => :push).size == patches.size
      end

      def self.active
        all(:revision.gt => 0)
      end

      def self.create_from_json(author, json_str, obsoletes)
        if obsoletes != 'no'
          old_patchset = first(:id => obsoletes.strip.to_i)
        end
        patch_arr = JSON::parse(json_str)
        messages = patch_arr.pop
        patches_arr = patch_arr.map do |p|
          Patch.new(
            :commit => p['hashes']['commit'],
            :author => p['author']['email'],
            :message => messages[p['hashes']['commit']] || 'No commit message set.',
            :commited_at => p['author']['date'],
          )
        end
        new_patchset = create(:author => author, :patches => patches_arr, :revision => old_patchset ? old_patchset.revision+1 : 1)
        old_patchset.update(:revision => -1) if new_patchset and old_patchset
        new_patchset
      end
    end

  end
end
