class ExportData

  attr_reader :data_cols
  attr_reader :dest_data_cols
  attr_reader :uploaded_files

  def initialize(**options)
    @config = options[:config]
    @path = "export_data"
    @base_dir = options[:base_dir]
    @data_template_path = options[:data_template]
    @data_dest_template_path = options[:data_dest_template]
    @dictionary_path = options[:data_dictionary]
    @data_cols = data_cols
    @dest_data_cols = dest_data_cols
    @data_dictionary = data_dictionary
    @file_cols = []
    find_file_fields
    add_files
  end

  def data_dictionary
    if File.exist? @dictionary_path
      CSV.read @dictionary_path, :headers => true, encoding: Encoding::ISO_8859_1
    else
      throw "Unable to find a data dictionary file for the project #{@dictionary_path}."
    end
  end

  def data_cols
    fetch_data_template
  end

  def fetch_data_template
    if File.exist? @data_template_path
      CSV.read @data_template_path, :headers => true, encoding: Encoding::ISO_8859_1
    else
      throw "Unable to find a data template file for the project #{@data_template_path}."
    end
  end

  def dest_data_cols
    fetch_dest_data_template
  end

  def fetch_dest_data_template
    if File.exist? @data_dest_template_path
      CSV.read @data_dest_template_path, :headers => true, encoding: Encoding::ISO_8859_1
    else
      throw "Unable to find a destination data template file for the project #{@data_dest_template_path}."
    end
  end

  def find_file_fields
    @data_dictionary.by_row.each { |r| @file_cols << r['field_name'] if r['field_type'] == 'file' }
  end

  def add_files
    @uploaded_files = {}
    @data_cols.each do |row|
      row.each do |col|
        add_field_to_hash(row, col) if file_column?(col) && doc_exists?(col)
      end
    end
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

  def file_column?(col)
    @file_cols.include?(col[0])
  end

  def doc_exists?(col)
    !col[1].nil?
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