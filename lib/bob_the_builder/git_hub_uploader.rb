module BobTheBuilder
  class GitHubUploader
    def initialize(username, password, repository)
      @username   = CGI.escape(username)
      @password   = CGI.escape(password)
      @repository = repository
    end

    def create(filename, file, description)
      url = "https://%s:%s@api.github.com/repos/%s/downloads" %
        [@username, @password, @repository]
      params = { 'name'        => File.basename(filename),
                 'size'        => File.size(file.path),
                 'description' => description }
      response = RestClient.post(url, params.to_json)
      upload_to_s3(JSON.parse(response.body), file)
    rescue
      puts $!.inspect
      raise
    end

    private
    def upload_to_s3(response, file)
      params = RUBY_VERSION < "1.9" ? OrderedHash.new : {}
      params['key']                   = response['path']
      params['acl']                   = response['acl']
      params['success_action_status'] = 201
      params['Filename']              = response['name']
      params['AWSAccessKeyId']        = response['accesskeyid']
      params['Policy']                = response['policy']
      params['Signature']             = response['signature']
      params['Content-Type']          = response['mime_type']
      params['file']                  = file
      params[:multipart]              = true
      RestClient.post(response['s3_url'], params)
    rescue
      puts $!.inspect
      raise
    end
  end
end
