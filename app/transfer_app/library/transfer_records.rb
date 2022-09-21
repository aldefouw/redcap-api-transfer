require 'csv'
require 'logger'
require 'colorize'
require 'mechanize'
require 'parallel'
require 'curb'

require 'digest/sha1'
require 'net/http'
require 'uri'

#Load Config
require_relative "config"
require_relative "export_data"
require_relative "reporting"

class TransferRecords

  def initialize(**options)
    options[:base_dir] = options.key?(:base_dir) ? options[:base_dir] : Dir.getwd
    @base_dir = options[:base_dir]

    @data_template = "#{@base_dir}/export_data/template-#{Time.now.to_i}.tmp"
    options = options.merge(data_template: @data_template)

    @data_dest_template = "#{@base_dir}/export_data/dest_template-#{Time.now.to_i}.tmp"
    options = options.merge(data_dest_template: @data_dest_template)

    @data_dictionary = "#{@base_dir}/export_data/dictionary-#{Time.now.to_i}.tmp"
    options = options.merge(data_dictionary: @data_dictionary)

    puts 'Loading Configuration ... '
    @config = Config.new(options)
    options = options.merge(config: @config)

    puts 'Downloading SOURCE Project Template ... '
    download_data_template

    # This only runs if "transfer_new_records_only: true"
    # *** MUST *** have export rights configured for API user on the destination side!
    if @config.new_records_only
      puts 'Downloading DESTINATION Project Template ... '
      download_dest_data_template
    end

    puts 'Downloading Data Dictionary ... '
    download_data_dictionary

    puts 'Loading Export Data ... '
    @export_data = ExportData.new(options)

    puts 'Loading Reporting Options ... '
    @reporting = Reporting.new(options)
  end

  def run
    Parallel.map(sliced_ids, in_processes: @config.processes){ |chunk| chunk.each { |id| transfer_record_to_destination(id) } }
  end

  def transfer_record_to_destination(id)
    Curl::Easy.http_post(@config.source_url, map_data_to_post_fields(source_fields(id))) do |curl|
      curl.verbose = @config.verbose
      curl.on_success do |r|
        transfer_destination_success(id)
        write_record_to_destination(id, r)
        fetch_field_documents(id)
      end
      curl_conditions(curl, id, 'source')
    end
  end

  private

  def transfer_destination_success(id)
    @reporting.info_output "Successfully fetched #{id} from source."
  end

  def data_dictionary_request
    {
      :token  =>  @config.source_token,
      :content => 'metadata',
      :format  => 'csv',
      :returnFormat => 'csv',
      :forms => ''
    }
  end

  def destination_fields(source_data)
    {
        :token  =>  @config.destination_token,
        :content => 'record',
        :format  => 'json',
        :type    => 'eav',
        :overwriteBehavior => 'overwrite',
        :data    => source_data,
        :returnContent => 'count',
        :returnFormat => 'json'
    }
  end

  def source_fields(id)
    {
        :token => @config.source_token,
        :content => 'record',
        :format => 'json',
        :type => 'eav',
        :records => id,
        :rawOrLabel => 'raw',
        :rawOrLabelHeaders => 'raw',
        :exportCheckboxLabel => 'true',
        :exportSurveyFields => 'true',
        :exportDataAccessGroups => 'false',
        :returnFormat => 'json'
    }
  end

  def file_fields(id, field, event)
    {
        :token => @config.source_token,
        :content => 'file',
        :action => 'export',
        :record => id,
        :field => field,
        :event => event_name(event)
    }
  end

  def import_file_fields(id, field, event_name)
    {
        :token => @config.destination_token,
        :content => 'file',
        :action => 'import',
        :record => id,
        :field => field,
        :event => event_name,
        :returnFormat => 'json'
    }
  end

  def export_file_from_source(id, field, event)
    Curl::Easy.http_post(@config.source_url, map_data_to_post_fields(file_fields(id, field, event))) do |curl|
      curl.verbose = @config.verbose
      curl.on_success do |r|
        export_file_success_message(id, r, event)
        write_file_to_local_disk(r, curl)
        import_file_to_destination(r, id, field, event_name(event), full_file_path(r))
      end
      curl_conditions(curl, id, 'source file')
    end
  end

  def export_file_success_message(id, r, event)
    @reporting.info_output "Successfully fetched source file called #{original_file_name(r)} from #{id} / #{event_name(event)} source."
  end

  def write_record_to_destination(id, response)
    Curl::Easy.http_post(@config.destination_url, map_data_to_post_fields(destination_fields(response.body_str))) do |curl|
      curl.verbose = @config.verbose
      curl.on_success { |r| write_success?(r) ? write_record_success(id, r) : write_record_failure(id, r) }
      curl_conditions(curl, id, 'destination')
    end
  end

  def write_success?(r)
    r.body_str == '{"count": 1}'
  end

  def write_record_success(id, r)
    @reporting.info_output "Successfully created #{id} on destination."
  end

  def write_record_failure(id, r)
    @reporting.error_output "There was a problem with #{id} on destination.  See below:"
    @reporting.error_output r.body_str
  end

  def import_file_to_destination(response, id, field, event_name, file)
    resp = upload_request(Digest::SHA1.hexdigest(Time.now.usec.to_s), id, field, event_name, file)
    upload_success?(resp) ? upload_success_msg(response, id, event_name, resp) : upload_failure_msg(response, id, event_name, resp)
  end

  def upload_success?(resp)
    resp.code == "200"
  end

  def upload_request(boundary, id, field, event_name, file)
    uri = URI.parse(@config.destination_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if @config.destination_url.include?('https://')
    http.set_debug_output($stdout) if @config.verbose
    req = Net::HTTP::Post.new(uri.request_uri)
    req.body = body(boundary, id, field, event_name, file)
    req['Content-Type'] = "multipart/form-data, boundary=#{boundary}"
    http.request req
  end

  def body(boundary, id, field, event_name, file)
    <<-EOF
--#{boundary}
Content-Disposition: form-data; name="file"; filename="#{File.basename(file)}"
Content-Type: application/octet-stream

#{File.read(file)}
--#{boundary}
#{import_file_fields(id, field, event_name).collect{|k,v|"Content-Disposition: form-data; name=\"#{k.to_s}\"\n\n#{v}\n--#{boundary}\n"}.join}
    EOF
  end

  def upload_success_msg(response, id, event_name, resp)
    if resp.body.include?("Error") || resp.body.include?("ERROR") || resp.body.include?("error")
      upload_failure_msg(response, id, event_name, resp)
    else
      @reporting.info_output "Successfully uploaded file #{original_file_name(response)} to #{id} / #{event_name} destination. Response: #{resp.body}"
    end
  end

  def upload_failure_msg(response, id, event_name, resp)
    @reporting.error_output "Error uploading file #{original_file_name(response)} to #{id} / #{event_name} on destination.  Possible reason: #{resp.body}"
  end

  def curl_conditions(curl, id, location)
    curl.on_redirect { |r| @reporting.error_output "Redirected for #{id} on #{location}. Possible reason: #{r.body}" }
    curl.on_missing { |r| @reporting.error_output "Missing for #{id} on #{location}. Possible reason: #{r.body}" }
    curl.on_failure do |r, err|
      @reporting.error_output "Failure for #{id} on #{location}. Possible reason: #{r.body}"
      @reporting.error_output "Error: #{err.inspect}"
    end
    curl.on_complete do
      @reporting.info_output "Completed request for #{id} on #{location}."
      curl.close
    end
  end

  def write_file_to_local_disk(r, curl)
    create_downloads_folder
    File.open(full_file_path(r), 'wb') { |f| f << curl.body }
  end

  def create_downloads_folder
    Dir.chdir(@base_dir)
    Dir.mkdir("downloaded_files") unless Dir.exist?("downloaded_files")
  end

  def sliced_ids
    unique_record_ids.count > @config.processes ? sliced_by_processes : single_slice
  end

  def sliced_by_processes
    unique_record_ids.each_slice(@config.processes).to_a
  end

  def single_slice
    [unique_record_ids]
  end

  def unique_record_ids
    @config.new_records_only ? source_ids - dest_ids : source_ids
  end

  def source_ids
    @export_data.data_cols.map { |r| record_id(r) }.uniq
  end

  def dest_ids
    @export_data.dest_data_cols.map { |r| record_id(r) }.uniq
  end

  def record_id(row)
    row.first[1]
  end

  def event_fields(event)
    event[1][:fields]
  end

  def event_name(event)
    event[0]
  end

  def map_data_to_post_fields(data)
    data.map{|k, v| Curl::PostField.content(k.to_s, v) unless v.nil? }
  end

  def original_file_name(response)
    response.content_type.split('"')[1]
  end

  def full_file_path(response)
    "#{@base_dir}/downloaded_files/#{original_file_name(response)}"
  end

  def fetch_field_documents(id)
    fields_with_documents(id) if @export_data.uploaded_files.key?(id)
  end

  def fields_with_documents(id)
    @export_data.uploaded_files[id].each { |event| all_event_fields(event, id) }
  end

  def all_event_fields(event, id)
    event_fields(event).each { |field| export_file_from_source(id, field, event) }
  end

  def all_data_from_source
    {
        :token => @config.source_token,
        :content => 'record',
        :format => 'csv',
        :rawOrLabel => 'raw',
        :rawOrLabelHeaders => 'raw',
        :exportCheckboxLabel => 'true',
        :exportSurveyFields => 'true',
        :exportDataAccessGroups => 'false',
        :returnFormat => 'json'
    }
  end

  def all_data_from_destination
    {
      :token => @config.destination_token,
      :content => 'record',
      :format => 'csv',
      :rawOrLabel => 'raw',
      :rawOrLabelHeaders => 'raw',
      :exportCheckboxLabel => 'true',
      :exportSurveyFields => 'true',
      :exportDataAccessGroups => 'false',
      :returnFormat => 'json'
    }
  end

  def download_data_template
    Curl::Easy.http_post(@config.source_url, map_data_to_post_fields(all_data_from_source)) do |curl|
      curl.verbose = @config.verbose
      curl.on_success do |r|
        File.open(@data_template, 'wb') { |f| f << r.body }
      end
      curl_data_template_conditions(curl, 'data dictionary')
    end
  end

  def download_dest_data_template
    Curl::Easy.http_post(@config.destination_url, map_data_to_post_fields(all_data_from_destination)) do |curl|
      curl.verbose = @config.verbose
      curl.on_success do |r|
        File.open(@data_dest_template, 'wb') { |f| f << r.body }
      end
      curl_data_template_conditions(curl, 'data dictionary')
    end
  end

  def download_data_dictionary
    Curl::Easy.http_post(@config.source_url, map_data_to_post_fields(data_dictionary_request)) do |curl|
      curl.verbose = @config.verbose
      curl.on_success do |r|
        File.open(@data_dictionary, 'wb') { |f| f << r.body }
      end
      curl_data_template_conditions(curl)
    end
  end

  def curl_data_template_conditions(curl, kind = 'data template')
    curl.on_redirect { |r| @reporting.error_output "Redirected when attempting to download #{kind}. Possible reason: #{r.body}" }
    curl.on_missing { |r| @reporting.error_output "Missing when attempting to download #{kind}. Possible reason: #{r.body}" }
    curl.on_failure do |r, err|
      @reporting.error_output "Failure when attempting to download #{kind}. Possible reason: #{r.body}"
      @reporting.error_output "Error: #{err.inspect}"
    end
    curl.on_complete do
      @reporting.info_output "Completed data template download."
      curl.close
    end
  end

  def delete_data_template
    File.delete(@data_template)
  end

end