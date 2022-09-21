require 'pry'

class Config

  attr_reader :source_url
  attr_reader :source_token

  attr_reader :destination_url
  attr_reader :destination_token

  attr_reader :settings

  attr_reader :verbose
  attr_reader :processes

  attr_reader :project_name

  attr_reader :new_records_only

  def initialize(**options)
    @base_dir = options.has_key?(:base_dir) ? options[:base_dir] : Dir.getwd
    @config_file = "#{@base_dir}/config/config.yml"
    @project_name = options[:project_name]
    load_auth_config
  end

  private

  def load_auth_config
    if File.exists?(@config_file)
      config_file = File.read(@config_file)
      @config = YAML.load(config_file)
      @projects = @config['projects']
      @settings = @config['settings']

      @processes = @config['settings']['processes'] #Pull in defaults
      @verbose = @config['settings']['verbose'] #Pull in defaults

      if @projects.has_key?(@project_name)
        @source_url = @projects[@project_name]['source']['url']
        @source_token = @projects[@project_name]['source']['token']

        @destination_url = @projects[@project_name]['destination']['url']
        @destination_token = @projects[@project_name]['destination']['token']

        @processes = @projects[@project_name]['processes']
        @verbose = @projects[@project_name]['verbose']

        #Transfer New Records Only flag defaults to false but accepts true if set within config.yml
        @new_records_only = false
        @new_records_only = @projects[@project_name]['transfer_new_records_only'] if @projects[@project_name].has_key?('transfer_new_records_only')
      else
        throw "Cannot find the project name #{@project_name} in config.yml."
      end

    else
      throw "Cannot find #{@config_file} file."
    end
  end

end