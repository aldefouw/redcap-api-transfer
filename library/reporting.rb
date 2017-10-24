class Reporting

  def initialize(options)
    @base_dir = options[:base_dir]

    create_errors_folder
    create_logs_folder

    @error_log = Logger.new(errors_log_path)
    @info_log = Logger.new(info_log_path)
  end

  def create_errors_folder
    Dir.chdir(@base_dir)
    Dir.mkdir("errors") unless Dir.exist?("errors")
  end

  def create_logs_folder
    Dir.chdir(@base_dir)
    Dir.mkdir("logs") unless Dir.exist?("logs")
  end

  def errors_log_path
    "#{@base_dir}/logs/errors.log"
  end

  def info_log_path
    "#{@base_dir}/logs/info.log"
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