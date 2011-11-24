module BobTheBuilder
  class Bob
    attr_reader :output, :environment, :repo

    def initialize(env, repo_location = '.', branch_name = 'master')
      @environment = env
      @repo = Git.open(repo_location)
      if repo.branches.any? { |br| br.name == branch_name }
        repo.branch(branch_name).checkout
      end
    end

    def version_bump!(change_type)
      unless change_type == 'patch' || change_type == 'minor' ||
        change_type == 'major'
        ohai "Change type not recognized selecting 'patch' as default value"
        type = 'patch'
      end

      @current_version = next_version(change_type)
      ohai "Updating git version"
      repo.add_tag(current_version)
      repo.push('origin', repo.branch.name, true)
      ohai "Git version updated to", current_version
    end

    def build(version = nil)
      version ||= current_version
      ohai "Updating submodules..."
      git('submodule init')
      git('submodule update')
      ohai "Submodules updated"
          
      ohai "Building..."
      options['date']    = Time.now.strftime("%Y-%m-%d")
      options['version'] = version
      FileUtils.mkdir_p(File.dirname(File.expand_path(option('output'))))
      run option('build_command')

      @output = option('output')
      ohai "Done! Compiled to", output
      output
    end

    def deploy(location = 'server')
      unless output
        ohai("In order to deploy there must be at least one build")
        return
      end

      if location == 'server'
        upload_to_server
      elsif location == 'github'
        upload_to_github
      else
        ohai "I don't know how to deploy to", location
      end
    end

    def changes_since_last_version?
      newer_commits.any? do |commit|
        commit.message =~ Regexp.new(option('changes_regexp'))
      end
    end

    private
    def upload_to_server
      [option('server')].flatten.compact.each do |server|
        ohai "Copying build to", server
        run("scp #{output} #{server}")
        ohai "Done!"
      end
    end

    def upload_to_github
      unless option('username', 'github') || option('password', 'github') ||
        option('repo', 'github')
        ohai "Missing GitHub credentials"
        return
      end

      ohai "Uploading to GitHub..."
      uploader = GitHubUploader.new option('username', 'github'),
        option('password', 'github'), option('repo', 'github')
      zip = Tempfile.new(File.basename(output))
      zip.write(buffer_from_output_zip)
      zip.rewind
      begin
        uploader.create(output + '.zip', zip, "v#{current_version}")
      ensure
        zip.close
        zip.unlink
      end
      ohai "Done!"
    end

    def buffer_from_output_zip
      Zip::Archive.open_buffer(Zip::CREATE) do |ar|
        base = File.basename(output)
        if File.directory?(output)
          ar.add_dir(base)
          Dir["#{output}/**/*"].each do |f|
            if File.directory?(f)
              ar.add_dir([base, File.basename(f)].join('/'))
            else
              ar.add_file([base, File.basename(f)].join('/'), f)
            end
          end
        else
          ar.add_file(base, output)
        end
      end
    end

    def newer_commits
      if current_version
        repo.log.between(current_version, 'HEAD')
      else
        repo.log
      end
    end

    def next_version(change_type = 'patch')
      version = current_version.split('.').map(&:to_i)
      (0...3).each { |i| version[i] ||= 0 }

      case change_type
      when 'patch'
        version[2] += 1
      when 'minor'
        version[1] += 1
        version[2]  = 0
      when 'major'
        version[0] += 1
        version[1]  = version[2] = 0
      else
        return '-1'
      end

      version[0...3].join('.')
    end

    def current_version
      @current_version ||= begin
        tags = repo.tags.sort do |a,b|
          repo.object(a.sha).date <=> repo.object(b.sha).date
        end
        tags.size.zero? ? '0.0.0' : tags.last.name
      end
    end

    def options
      @options ||= begin
        file = if File.exist?(Dir.pwd + '/config.yml')
          'config.yml'
        elsif File.exist?(Dir.pwd + '/script/config.yml')
          'script/config.yml'
        else
          ohai "config.yml should be placed either in where you are running",
            "this script, or in the script folder."
          raise
        end
        YAML.load(File.read file)
      end
    end

    def option(option, namespace = nil)
      env = namespace || environment
      option = ENV[[env, option].join('_').upcase] ||
        ENV[[env, option].join('_').downcase] ||
        ENV[option.upcase] || ENV[option.downcase] ||
        # Fails in new git versions (1.7.5+)
        #RUBY_VERSION < '1.9' &&
        #!repo.config(['bob', env, option].join('.')).empty? &&
        #repo.config(['bob', env, option].join('.')) ||
        #RUBY_VERSION < '1.9' &&
        #!repo.config(['bob', option].join('.')).empty? &&
        #repo.config(['bob', option].join('.')) ||
        options[env] && options[env][option] || options[option]

      return unless option
      apply_options(option)
    end

    def apply_options(input)
      input.gsub(/\{\{([\w-]+)\}\}/) { option $1 }
    end

    def git(cmd)
      run('git ' + cmd)
    end

    def run(cmd)
      result = `#{cmd}`.chomp
      raise 'Runtime Error executing command: ' + cmd unless $?.success?

      result
    end

    def ohai(*msg)
      puts "=> #{msg.join(' ')}"
    end
  end
end
