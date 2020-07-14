class Reporting

  def initialize(options)
    @base_dir = options[:base_dir]
    @error_log = Logger.new(errors_log_path)
    @info_log = Logger.new(info_log_path)
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