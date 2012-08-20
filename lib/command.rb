module Tracker
  module Cmd

    require 'yaml'
    require 'json'
    require 'base64'

    GIT_JSON_FORMAT = '{ "hashes":'+
      '{ "commit":"%H", "tree":"%T",'+' "parents":"%P" },'+
      '"author":{ "date": "%ai", "name": "%an", "email":"%ae" },'+
      '"committer":{ "date": "%ci", "name": "%cn", "email":"%ce" } },'

    GIT_OPTS = "--format='#{GIT_JSON_FORMAT}'"

    GIT_CMD = 'git --no-pager log origin/master..HEAD %s ' % GIT_OPTS

    def self.default_configuration
      {
        :url => 'http://localhost:9292',
        :user => 'mfojtik@redhat.com',
        :password => 'test123'
      }
    end

    # Set/Get configuration for the command-line client
    #
    # * +conf+ - Set configuration:
    #
    # * +:url+          - Tracker server URL (default: http://localhost:9292)
    # * +:user+         - Tracker username
    # * +:password+*    - Tracker password
    #
    def self.configuration(conf=nil); @configuration ||= conf; end

    # Retrieve/Set the configuration from YAML file, if YAML file does not
    # exists, use the +default_configuration+ instead
    #
    # * +action+       - If action :set then overide the default_configuration (default: :get)
    # * +:opts+        - Read YAML file from opts[:file]
    #
    def self.config(action=:get, opts={})
      configuration(YAML.load_file(opts[:file])) if (action == :set) && File.exists?(opts[:file])
      configuration || configuration(default_configuration)
    end

    # Read commits between origin/master..HEAD and convert them to JSON string
    #
    # * +directory+   - If given, cmd app will 'chdir' into that directory (default: nil)
    #
    def self.patches_to_json(directory=nil)
      patches_in_json = git_cmd(GIT_CMD, directory)
      commit_messages_raw = git_cmd('git log --pretty=oneline origin/master..HEAD', directory)
      commit_messages = commit_messages_raw.each_line.map.inject({}) do |result, line|
        hash, message = line.split(' ', 2)
        result[hash] = message.strip
        result
      end
      "[#{patches_in_json}#{JSON::dump(commit_messages)}]"
    end

    # Method will call +patches_to_json+ and POST the JSON array to Tracker
    # server. Authentication stored in +config+ is used.
    #
    # * +directory+ - If given, cmd app will 'chdir' into that directory (default: nil)
    #
    def self.record(directory, obsolete=nil)
      number_of_commits = JSON::parse(patches_to_json(directory)).pop.size
      begin
        response = RestClient.post(
          config[:url] + '/set',
          patches_to_json(directory),
          {
            :content_type => 'application/json',
            'Authorization' => "Basic #{basic_auth}",
            'X-Obsoletes' => obsolete || 'no'
          }
        )
        response = JSON::parse(response)
        "#{number_of_commits} patches were recorded to the tracker server"+
          " [#{config[:url]}][##{response['id']}][rev#{response['revision']}]"
      rescue => e
        e.message
      end
    end

    def self.upload(directory)
      diffs = git_cmd('git format-patch --stdout master', directory)
      patches = {}
      current_patch_commit = ''
      diffs.each_line do |line|
        if line =~ %r[^From (\w{40}) ]
          current_patch_commit = $1
          patches[current_patch_commit] = line
        else
          patches[current_patch_commit] += line
        end
      end
      begin
        patches.each do |commit, body|
          puts '[^] %s' % commit
          upload_patch_body(commit, body)
        end
        '%i patches were uploaded to tracker [%s]' % [patches.size, config[:url]]
      rescue => e
        e.message
      end
    end

    def self.upload_patch_body(commit_id, body)
      RestClient.put(
        config[:url] + ('/patch/%s/body' % commit_id),
        body,
        {
          :content_type => 'application/json',
          'Authorization' => "Basic #{basic_auth}"
        }
      )
    end

    def self.download_patch_body(commit_id)
      RestClient.get(
        config[:url] + ('/patch/%s/download' % commit_id),
        {
          :content_type => 'application/json',
          'Authorization' => "Basic #{basic_auth}"
        }
      )
    end

    def self.download(directory, patchset_id)
      patches = []
      begin
        response = RestClient.get(
          config[:url] + ('/set/%s' % patchset_id),
          {
            'Accept' => 'application/json',
            'Authorization' => "Basic #{basic_auth}"
          }
        )
        patches = JSON::parse(response)['patches'].map { |p| p['commit'] }
      rescue => e
        puts "ERR: #{e.message}"
        exit
      end
      counter = 0
      puts
      patches.each do |commit|
        File.open(File.join(directory, "#{counter}-#{commit}.patch"), 'w') { |f|
          f.puts download_patch_body(commit)
        }
        puts '[v] %s-%s.patch' % [counter, commit]
        counter += 1
      end
      puts "\n -> #{counter} patches downloaded."
      ''
    end

    def self.obsolete_patchset(patchset_id)
      RestClient.post(
        config[:url] + ('/patchset/%s/obsolete' % patchset_id), '',
        {
          :content_type => 'application/json',
          'Authorization' => "Basic #{basic_auth}"
        }
      )
      puts 'This record marked patchset [#%s] as obsoleted.'
    end

    # Method perform given action on GIT branch with recorded commits.
    # The patches **need** to be recorded on Tracker server to perfom any
    # action. 
    #
    # * +name+  - Action name (:ack, :nack, :push)
    # * +directory+ - If given, cmd app will 'chdir' into that directory (default: nil)
    #
    def self.action(name, directory, options={})
      patches = JSON::parse(patches_to_json(directory))
      messages = patches.pop
      puts
      patches.each do |p|
        begin
          RestClient.post(
            config[:url] + ('/patch/%s/%s' % [p['hashes']['commit'], name]),
            {
              :message => options[:message]
            },
            {
              :content_type => 'application/json',
              'Authorization' => "Basic #{basic_auth}"
            }
          )
          puts '[%s][%s] %s' % [name.to_s.upcase, p['hashes']['commit'][-8, 8], messages[p['hashes']['commit']]]
        rescue => e
          puts '[ERR] %s' % e.message
        end
      end
      "  |\n  |--------> [%s]\n\n" % config[:url]
    end

    def self.ack(directory, opts={}); action(:ack, directory, opts); end
    def self.nack(directory, opts={}); action(:nack, directory, opts); end
    def self.push(directory, opts={}); action(:push, directory, opts); end

    def self.status(directory)
      patches = JSON::parse(patches_to_json(directory))
      # Remove messages from Array
      patches.pop
      puts
      counter = 0
      patches.each do |p|
        begin
          response = RestClient.get(
            config[:url] + ('/patch/%s' % p['hashes']['commit']),
            {
              'Accept' => 'application/json',
              'Authorization' => "Basic #{basic_auth}"
            }
          )
          response = JSON::parse(response)
          puts '[%s][%s][rev%s] %s' % [
            response['commit'][-8, 8],
            response['status'].upcase,
            response['revision'],
            response['message']
          ]
          counter+=1
        rescue => e
          next if response == 'null'
          puts '[ERR][%s] %s' % [p['hashes']['commit'][-8, 8], e.message]
        end
      end
      if counter == 0
        "ERR: This branch is not recorded yet. ($ tracker record)\n\n"
      else
        "  |\n  |--------> [%s]\n\n" % config[:url]
      end
    end

    private

    # Execute GIT command ('git') in the specified directory. Method will then
    # revert pwd to its original value and return command output in string.
    #
    # * +cmd+ - GIT command to perform (eg. 'git log')
    #
    def self.git_cmd(cmd, directory)
      old_pwd = Dir.pwd
      result = ''
      begin
        Dir.chdir(directory)
        result = %x[#{cmd}]
      rescue => e
        puts "ERROR: #{e.message}"
        exit(1)
      ensure
        Dir.chdir(old_pwd)
      end
      result
    end

    def self.basic_auth
     Base64.encode64("#{config[:user]}:#{config[:password]}")
    end

  end
end
