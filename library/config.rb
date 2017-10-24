class Config

  attr_reader :source_url
  attr_reader :source_token

  attr_reader :destination_url
  attr_reader :destination_token

  def initialize(**options)
    @base_dir = options[:base_dir]
    load_auth_config
  end

  private

  def load_auth_config
    if File.exists?(@base_dir + "/config/config.yml")
      config_file = File.read(@base_dir + "/config/config.yml")
      @config = YAML.load(config_file)

      @source_url = @config.source_url
      @source_token = @config.source_token

      @destination_url = @config.destination_url
      @destination_token = @config.destination_token
    else
      throw "Cannot find a config.yml file."
    end
  end

end