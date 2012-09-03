module Tracker
  module Models

    # Initialize DataMapper
    #
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
      property :summary, Text
      property :commited_at, DateTime
      property :status, Enum[ :new, :ack, :nack, :push ], :default => :new
      property :updated_by, String
      property :revision, Integer
      property :body, Text

      property :created_at, DateTime
      property :updated_at, DateTime

      belongs_to :patch_set

      has n, :logs, :constraint => :destroy

      def short_commit
        commit[0, 8]
      end

      def human_name
        "[#{current_index}/#{patch_set.num_of_patches}] #{message[0..90].strip}"
      end

      # Method counts patches that share same commit id
      # Usualy they are older versions of the current patch and this
      # number is then used as a patch version
      #
      def count_same_commit
        Patch.all(:commit => commit).count - 1
      end

      # Attach the output of 'git format-patch' to patch
      #
      def attach!(diff)
        update!(:body => diff)
      end

      # Return the first 'active' patch identified by the commit id.
      # There could be many patches with the same commit id, but just the
      # first one that is not in obsoleted set is considered as 'active'
      #
      # The commit_id could be 8 length unique commit hash or full hash
      #
      def self.active(commit_id)
        return if commit_id.nil?
        if commit_id.length == 8
          commit_query = { :commit.like => "#{commit_id}%" }
        else
          commit_query = { :commit => commit_id }
        end
        commit_query.merge!(:order => [ :id.desc ])
        all(commit_query).find { |p| !p.obsoleted? }
      end

      # The patch is obsoleted if the patch set that include that patch
      # has revision set to -1
      #
      def obsoleted?
        return true if patch_set.nil?
        patch_set.revision <= 0
      end

      def update_status!(new_state, author, message=nil)
        new_state = status.to_s if new_state.intern == :note
        update!(:status => new_state.intern, :updated_by => author)
        (logs << Log.create(:message => message || '', :author => author, :action => new_state.to_s)) && save
        reload
        patch_set.refresh_status!
        self
      end

      # Return the other patches in the same patch set
      #
      def other_patches
        patch_set.patches.all(:order => [ :id.asc ]).reject { |p| p == self }
      end

      def current_index
        1 + patch_set.patches.all(:order => [:id.asc ]).index(self)
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

    class Build
      include DataMapper::Resource

      property :id, Serial
      property :state, String
      property :install, Text
      property :build, Text
      property :patches, Text
      property :created_at, DateTime

      belongs_to :patch_set
    end

    class PatchSet
      include DataMapper::Resource

      property :id, Serial
      property :author, String
      property :revision, Integer, :default => 1
      property :created_at, DateTime
      property :status, String, :default => 'new'

      has n, :patches, :constraint => :destroy
      has 1, :build, :constraint => :destroy

      # Return the commit message of the first patch in set.
      # Usually this message is used as a set name
      #
      def first_patch_message
        return 'No patches recorded in this set' if patches.empty?
        patches.first(:order => [ :id.asc ]).message
      end

      #get commit messages for all patches in set, used for index page
      #(will most likely be truncated to some max chars length)
      def all_patches_message
        return 'No patches recorded in this set' if patches.empty?
        all_patches = patches.all(:order => [:id.asc])
        message = ""
        all_patches.each_index do |i|
          message << "#{i}/#{all_patches.size}: #{all_patches[i].message} &&"
        end
        message.chomp("&&")
      end

      # Check if all patches in this set has given status
      #
      def acked?; all_status?(:ack); end
      def nacked?; all_status?(:nack); end
      def pushed?; all_status?(:push); end

      def all_status?(s)
        patches.all(:status => s).size == patches.all.count
      end

      # Return only non-obsoleted patches
      #
      def self.active
        all(:revision.gt => 0, :order => [ :id.desc ])
      end

      # Mark the set as obsolete
      #
      def obsolete!
        update!(:revision => -1)
      end

      # The set has 'status' field that cache the status
      # of all patches in set. This method is called every 
      # time when patch in current set is updated
      #
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
          summary = messages[p['hashes']['commit']]['full_message']
          # Remove the 'commit' on first line and TrackedAt header:
          summary = summary.each_line.map.to_a[1..-2].join("\n") if !summary.empty?
          Patch.new(
            :commit => p['hashes']['commit'],
            :author => p['author']['email'],
            :message => messages[p['hashes']['commit']]['msg'].strip || 'Patch does not have commit message',
            :summary => summary,
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
