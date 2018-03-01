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

class UpdateRecords

  def initialize(**options)
    @processes = options[:processes] || 8

    @report_ids = options[:report_ids]

    @base_dir = Dir.getwd
    options = options.merge(base_dir: @base_dir)

    puts 'Loading Configuration ... '
    @config = Config.new(options)

    options = options.merge(config: @config)

    puts 'Loading Reporting Options ... '
    @reporting = Reporting.new(options)
  end

  def run
    Parallel.map(sliced_ids, in_processes: @processes){ |chunk| chunk.each { |id| update_records(id) } }
  end

  def update_records(report)
    Curl::Easy.http_post(@config.source_url, map_data_to_post_fields(source_fields(report))) do |curl|
      curl.on_success do |r|
        transfer_destination_success(report)
        write_record_to_destination(report, r)
      end
      curl_conditions(curl, report, 'source')
    end
  end

  private

  def transfer_destination_success(id)
    @reporting.info_output "Successfully fetched #{id} from source."
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

  def source_fields(report)
    {
        :token => @config.source_token,
        :content => 'report',
        :format => 'json',
        :report_id => report,
        :rawOrLabel => 'raw',
        :rawOrLabelHeaders => 'raw',
        :exportCheckboxLabel => 'false',
        :returnFormat => 'json'
    }
  end

  def version_3_1_forms
    ['ivp_b5', 'fvp_b5', 'tvp_b5']
  end

  def write_record_to_destination(id, response)
    if response.nil?

      binding.pry

    else

      in_json = JSON.parse(response.body_str)

      if in_json[0].to_a[2].nil?
        puts "No key exists"
      else
        current_field = in_json[0].to_a[2][0]
        form = in_json[0].to_a[3][0].split("_complete")[0]
      end

      puts "==== Form #{form} | Field: #{current_field} ============================"

      in_json.each do |r|
        ar = r.to_a
        id = r['ptid']
        event_name = r['redcap_event_name']
        !ar[2].nil? ? form_ver = ar[2][1]  : form_ver = ''
        !ar[3].nil? ? status = ar[3][1] : status = ''
        type = current_field.split("_").last

        if !status.nil? && (status == "1" || status == "2")

          if type == "adcid" #Set the ADCID to 37 for all where it is null
            update_record(id, current_field, "37", event_name)
          elsif type == "formver" && !version_3_1_forms.include?(form) #Set the Form Version to 3 for all except IVP B5, FVP B5, and TVP B5
            update_record(id, current_field, "3", event_name)
          elsif type == "formver" && version_3_1_forms.include?(form) #Set the Form Version to 3.1 for IVP B5, FVP B5, TVP B5
            update_record(id, current_field, "3.1", event_name)
          end

        elsif !status.nil? && status == "0"
          @reporting.info_output "#{id} | #{event_name} | Status is 'Incomplete.'  This record should not be updated.".red
        else
          @reporting.info_output "#{id} | #{event_name} | No status.  This record should not be updated.".red
        end
      end
    end
  end

  def update_record(id, field, value, event_name)
    record = { :record => id, :ptid => id, :redcap_event_name => event_name, field_name: field, value: value }
    data = [record].to_json

    @reporting.info_output "#{id} | #{event_name} | Set #{field} to #{value}."

    ch = Curl::Easy.http_post(@config.destination_url, map_data_to_post_fields(destination_fields(data))) do |curl|
      curl.on_success { |r| write_success?(r) ? write_record_success(id, r) : write_record_failure(id, r) }
      curl_conditions(curl, "#{event_name} | #{id} | #{field} : #{value}", 'destination')
    end

    ch.body_str
  end

  def write_success?(r)
    r.body_str == '{"count": 1}'
  end

  def write_record_success(id, r)
    @reporting.info_output "Successfully updated #{id} on destination."
  end

  def write_record_failure(id, r)
    @reporting.error_output "There was a problem with #{id} on destination.  See below:"
    @reporting.error_output r.body_str
  end

  def upload_success?(resp)
    resp.code == "200"
  end

  def upload_request(boundary, id, field, event_name, file)
    uri = URI.parse(@config.destination_url)

    Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == "https") do |http|
      req = Net::HTTP::Post.new(uri.request_uri)
      req.body = body(boundary, id, field, event_name, file)
      req['Content-Type'] = "multipart/form-data, boundary=#{boundary}"
      http.request req
    end
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

  def curl_conditions(curl, id, location)
    curl.on_redirect { |r| @reporting.error_output "Redirected for #{id} on #{location}. Possible reason: #{r.body}" }
    curl.on_missing { |r| @reporting.error_output "Missing for #{id} on #{location}. Possible reason: #{r.body}" }
    curl.on_failure { |r| @reporting.error_output "Failure for #{id} on #{location}. Possible reason: #{r.body}" }
    curl.on_complete { @reporting.info_output "Completed request for #{id} on #{location}." }
  end

  def sliced_ids
    unique_record_ids.count > @processes ? sliced_by_processes : single_slice
  end

  def sliced_by_processes
    unique_record_ids.each_slice(@processes).to_a
  end

  def single_slice
    [unique_record_ids]
  end

  def unique_record_ids
    @report_ids
  end

  def map_data_to_post_fields(data)
    data.map{|k, v| Curl::PostField.content(k.to_s, v)}
  end

end