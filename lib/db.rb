module Tracker
  module Models

    def self.included(base)
      DataMapper::Logger.new($stdout, :debug)
      begin
        load File.join(File.dirname(__FILE__), '..', 'config', 'database.rb')
      rescue LoadError
        puts 'Please configure your database in config/database.rb'
        puts $!.message
        exit(1)
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
      property :body, Text

      property :created_at, DateTime
      property :updated_at, DateTime

      belongs_to :patch_set

      has n, :logs, :constraint => :destroy

      def count_same_commit
        Patch.all(:commit => commit).count - 1
      end

      def attach!(diff)
        update!(:body => diff)
      end

      def self.active(commit_id)
        all(:commit => commit_id, :order => [ :created_at.desc ]).select do |p|
          !p.obsoleted?
        end.first
      end

      def obsoleted?
        return true if patch_set.nil?
        patch_set.revision <= 0
      end

      def update_status!(new_state, author, message=nil)
        new_state = status.to_s if new_state.intern == :note
        update(:status => new_state.intern, :updated_by => author)
        message ||= '-'
        (logs << Log.create(:message => message, :author => author, :action => new_state.to_s)) && save
        [200, {}, self.to_json]
      end

      def other_patches
        patch_set.patches.reject { |p| p == self}
      end

      after :update do |p|
        p.patch_set.refresh_status!
      end

    end

    class Log
      include DataMapper::Resource

      property :id, Serial
      property :message, Text
      property :author, String
      property :created_at, DateTime
      property :action, String

      belongs_to :patch
    end

    class PatchSet
      include DataMapper::Resource

      property :id, Serial
      property :author, String
      property :revision, Integer, :default => 1
      property :created_at, DateTime
      property :status, String, :default => 'new'

      has n, :patches, :constraint => :destroy

      attr_accessor :patches_ids

      def first_patch_message
        return 'Empty set' if patches.empty?
        patches.first(:order => [ :id.asc ]).message
      end

      def with_commits
        @patches_ids ||= self.patches.map { |p| p.commit }
        self
      end

      def acked?; all_status?(:ack); end
      def nacked?; all_status?(:nack); end
      def pushed?; all_status?(:push); end

      def all_status?(s)
        patches.all(:status => s).size == patches.all.count
      end

      def self.active
        all(:revision.gt => 0)
      end

      def obsolete!
        update(:revision => -1)
      end

      def refresh_status!
        update!(:status => 'new') if status.nil?
        update!(:status => 'ack') if acked?
        update!(:status => 'nack') if nacked?
        update!(:status => 'push') if pushed?
      end

      def num_of_patches
        patches.count
      end

      def self.create_from_json(author, json_str, old_patchset_id)
        old_patchset = first(:id => old_patchset_id.strip.to_i) if old_patchset_id != 'no'
        patch_arr = JSON::parse(json_str)
        messages = patch_arr.pop
        patches_arr = patch_arr.map do |p|
          Patch.new(
            :commit => p['hashes']['commit'],
            :author => p['author']['email'],
            :message => messages[p['hashes']['commit']] || 'Patch does not have commit message',
            :commited_at => p['author']['date'],
          )
        end
        new_patchset = create(
          :author => author,
          :patches => patches_arr,
          :revision => old_patchset ? old_patchset.revision+1 : 1
        )
        old_patchset.obsolete! if new_patchset and old_patchset
        new_patchset
      end
    end

  end
end
