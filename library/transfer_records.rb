require 'pry'
require 'csv'
require 'watir'
require 'logger'
require 'colorize'
require 'mechanize'
require 'parallel'
require 'highline'
require 'ruby-progressbar'
require 'curb'

require 'digest/sha1'
require 'net/http'
require 'uri'

#Load Config
require "#{Dir.getwd}/library/config"
require "#{Dir.getwd}/library/export_data"
require "#{Dir.getwd}/library/reporting"

class TransferRecords

  def initialize(**options)
    @processes = options[:processes] || 8

    @base_dir = Dir.getwd
    options = options.merge(base_dir: @base_dir)

    puts 'Loading Configuration ... '
    @config = Config.new(options)

    options = options.merge(config: @config)

    puts 'Loading Export Data ... '
    @export_data = ExportData.new(options)

    puts 'Loading Reporting Options ... '
    @reporting = Reporting.new(options)
  end

  def run
    Parallel.map(sliced_ids){ |chunk| chunk.each { |id| get_record(id) } }
  end

  private

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

  def map_data_to_post_fields(data)
    data.map{|k, v| Curl::PostField.content(k.to_s, v)}
  end

  def get_record(id)
    Curl::Easy.http_post(@config.source_url, map_data_to_post_fields(source_fields(id))) do |curl|
      curl.on_success do |r|
        @reporting.info_output "Successfully fetched #{id} from source."
        write_record_to_destination(id, r)
        fetch_field_documents(id)
      end

      curl_conditions(curl, id, 'source')
    end
  end


  def record_id(row)
    row.first[1]
  end

  def sliced_ids
    if unique_record_ids.count > @processes
      unique_record_ids.each_slice(@processes).to_a
    else
      [unique_record_ids]
    end
  end

  def unique_record_ids
    @export_data.data_cols.map { |r| record_id(r)   }.uniq
  end

  def original_file_name(response)
    response.content_type.split('"')[1]
  end

  def full_file_path(response)
    "#{@base_dir}/downloaded_files/#{original_file_name(response)}"
  end

  def export_file_from_source(id, field, event)
    Curl::Easy.http_post(@config.source_url, map_data_to_post_fields(file_fields(id, field, event))) do |curl|
      curl.on_success do |r|
        @reporting.info_output "Successfully fetched source file called #{original_file_name(r)} from #{id} / #{event_name(event)} source."
        write_file_to_local_disk(r, curl)
        import_file_to_destination(r, id, field, event_name(event))
      end

      curl_conditions(curl, id, 'source file')
    end
  end

  def write_file_to_local_disk(response, curl)
    File.open(full_file_path(response), 'wb') { |f| curl.on_body {|data| f << data; data.size } }
  end

  def import_file_to_destination(response, id, field, event_name)
    file = full_file_path(response)
    boundary = Digest::SHA1.hexdigest(Time.now.usec.to_s)

body = <<-EOF
--#{boundary}
Content-Disposition: form-data; name="file"; filename="#{File.basename(file)}"
Content-Type: application/octet-stream

#{File.read(file)}
--#{boundary}
#{import_file_fields(id, field, event_name).collect{|k,v|"Content-Disposition: form-data; name=\"#{k.to_s}\"\n\n#{v}\n--#{boundary}\n"}.join}

EOF

    uri = URI.parse(@config.destination_url)
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Post.new(uri.request_uri)
    req.body = body
    req['Content-Type'] = "multipart/form-data, boundary=#{boundary}"
    resp = http.request(req)

    if resp.code == "200"
      @reporting.info_output"Successfully uploaded file #{original_file_name(response)} to #{id} / #{event_name} destination."
    else
      @reporting.error_output"Error uploading file #{original_file_name(response)} to #{id} / #{event_name} on destination.".red
    end
  end

  def fetch_field_documents(id)
    fields_with_documents(id) if @export_data.uploaded_files.key?(id)
  end

  def fields_with_documents(id)
    @export_data.uploaded_files[id].each do |event|
      event_fields(event).each do |field|
        export_file_from_source(id, field, event)
      end
    end
  end

  def event_fields(event)
    event[1][:fields]
  end

  def event_name(event)
    event[0]
  end


  def write_record_to_destination(id, response)
    Curl::Easy.http_post(@config.destination_url, map_data_to_post_fields(destination_fields(response.body_str))) do |curl|
      curl.on_success do |r|
        if r.body_str == '{"count": 1}'
          @reporting.info_output "Successfully created #{id} on destination."
        else
          @reporting.error_output "There was a problem with #{id} on destination.  See below:"
          @reporting.error_output r.body_str
        end
      end

      curl_conditions(curl, id, 'destination')
    end
  end

  def curl_conditions(curl, id, location)
    curl.on_redirect { @reporting.error_output "Redirected for #{id} on #{location}." }
    curl.on_missing { @reporting.error_output "Missing for #{id} on #{location}." }
    curl.on_failure { @reporting.error_output "Failure for #{id} on #{location}." }
    curl.on_complete { @reporting.info_output "Completed request for #{id} on #{location}." }
  end

end