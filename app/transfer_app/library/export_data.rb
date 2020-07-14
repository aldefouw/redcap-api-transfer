class ExportData

  attr_reader :data_cols
  attr_reader :uploaded_files

  def initialize(**options)
    @config = options[:config]
    @path = "export_data"
    @base_dir = options[:base_dir]
    @data_template = options[:data_template]
    @data_cols = data_cols
    files
  end

  def data_cols
    if File.exist? @data_template
      CSV.read @data_template, :headers => true
    else
      throw "Unable to find a data template file for the project #{@data_template}."
    end
  end

  def files
    @uploaded_files = {}
    @data_cols.each { |row| row.each { |col| add_field_to_hash(row, col) if doc_exists?(col) } }
  end

  def add_field_to_hash(row, col)
    add_record_key(row)
    add_event_hash(row)
    add_fields_hash(row)
    add_field(row, col)
  end

  def record_id(row)
    row[0]
  end

  def event(row)
    row[1]
  end

  def field_name(col)
    col[0]
  end

  def doc_exists?(col)
    col[1] == "[document]"
  end

  def add_record_key(row)
    @uploaded_files[record_id(row)] = {} unless @uploaded_files.key?(record_id(row))
  end

  def add_event_hash(row)
    @uploaded_files[record_id(row)][event(row)] = {} unless @uploaded_files[record_id(row)].key?(event(row))
  end

  def add_fields_hash(row)
    @uploaded_files[record_id(row)][event(row)][:fields] = [] unless @uploaded_files[record_id(row)][event(row)].key?(:fields)
  end

  def add_field(row, col)
    @uploaded_files[record_id(row)][event(row)][:fields] << field_name(col)
  end

end