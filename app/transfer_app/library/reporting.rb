class Reporting

  def initialize(options)
    @base_dir = options[:base_dir]
    @project_name = options[:config].project_name
    @error_log = Logger.new(errors_log_path)
    @info_log = Logger.new(info_log_path)
  end

  def create_logs_folders
    Dir.chdir("#{@base_dir}/logs/")
    Dir.mkdir(@project_name) unless Dir.exist?("#{@base_dir}/logs/#{@project_name}/")
  end

  def errors_log_path
    create_logs_folders
    "#{@base_dir}/logs/#{@project_name}/errors.log"
  end

  def info_log_path
    create_logs_folders
    "#{@base_dir}/logs/#{@project_name}/info.log"
  end

  def info_output(text)
    puts text.green
    @info_log.info(text)
  end

  def error_output(text)
    puts text.red
    @error_log.error(text)
  end

end