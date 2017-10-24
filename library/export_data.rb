class ExportData

  attr_reader :data_cols

  def initialize(**options)
    @config = options[:config]
    @path = "project_exports"
    @base_dir = options[:base_dir]
    @data_cols = data_cols
  end

  def data_file
    "#{@base_dir}/#{@path}/data.csv"
  end

  def data_cols
    if File.exist? data_file
      CSV.read data_file, :headers => true
    else
      throw "You need to add a data export file (data.csv) for project to #{data_file}."
    end
  end

end