class Reporting

  def initialize(options)
    @base_dir = options[:base_dir]

    create_errors_folder
    create_logs_folder
    #make_errors_csv

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

  # def errors_csv_path
  #   "#{@base_dir}/errors/errors.csv"
  # end

  def info_output(text)
    puts text.green
    @info_log.info(text)
  end

  def error_output(text)
    puts text.red
    @error_log.error(text)
  end

  # def make_errors_csv
  #   if @project.longitudinal
  #     CSV.open(errors_csv_path, "wb") { |csv| csv << ["record_id", "redcap_event_name", "instrument", "field", "case_report_form_value", "export_form_value", "url"] }
  #   else
  #     CSV.open(errors_csv_path, "wb") { |csv| csv << ["record_id", "instrument", "field", "case_report_form_value", "export_form_value", "url"] }
  #   end
  # end

  # def add_error_to_file(record:, instrument:, field:, case_report_value:, export_value:, url:)
  #   CSV.open(errors_csv_path, "a+") do |csv|
  #     csv << csv_error_row(record: record,
  #                          instrument: instrument,
  #                          field: field,
  #                          case_report_value: case_report_value,
  #                          export_value: export_value,
  #                          url:  url)
  #   end
  # end
  #
  # def csv_error_row(record:, instrument:, field:, case_report_value:, export_value:, url:)
  #   if @project.longitudinal
  #     [record[0], record["redcap_event_name"], instrument, field, case_report_value, export_value, url]
  #   else
  #     [record[0], instrument, field, case_report_value, export_value, url]
  #   end
  # end

end