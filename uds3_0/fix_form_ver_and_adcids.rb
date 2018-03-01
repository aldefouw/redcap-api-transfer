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

require "#{Dir.getwd}/../library/config"

puts 'Loading Configuration ... '
@config = Config.new(base_dir: "#{Dir.getwd}/../")

class Update

  def initialize(options)
    @config = options[:config]
  end

  def fetch_records(report)
    data = {
        :token => @config.source_token,
        :content => 'report',
        :format => 'json',
        :report_id => report,
        :rawOrLabel => 'raw',
        :rawOrLabelHeaders => 'raw',
        :exportCheckboxLabel => 'false',
        :returnFormat => 'json'
    }

    ch = Curl::Easy.http_post @config.source_url, data.collect{|k, v| Curl::PostField.content(k.to_s, v)} do |curl|
      curl_conditions(curl, report, 'fetch')
    end
    ch.body_str
  end

  def update_record(id, field, value, event_name)
    puts "#{id} | #{event_name} | Set #{field} to #{value}.".green

    record = { :record => id, :ptid => id, :redcap_event_name => event_name, field_name: field, value: value }
    data = [record].to_json

    fields = {
        :token => @config.destination_token,
        :content => 'record',
        :format => 'json',
        :type => 'eav',
        :data => data,
    }

    ch = Curl::Easy.http_post @config.source_url, fields.collect{|k, v| Curl::PostField.content(k.to_s, v)} do |curl|
      curl_conditions(curl, id, 'update')
    end
    ch.body_str
  end

  def curl_conditions(curl, id, location)
    curl.on_redirect { |r| puts "Redirected for #{id} on #{location}. Possible reason: #{r.body}" }
    curl.on_missing { |r| puts "Missing for #{id} on #{location}. Possible reason: #{r.body}" }
    curl.on_failure { |r| puts "Failure for #{id} on #{location}. Possible reason: #{r.body}" }
    curl.on_complete { puts "Completed request for #{id} on #{location}." }
  end

end

report_ids = [1372,
              1401,
              1374,
              1402,
              1375,
              1403,
              1376,
              1404,
              1377,
              1405,
              1373,
              1406,
              1378,
              1407,
              1379,
              1408,
              1380,
              1409,
              1381,
              1410,
              1382,
              1411,
              1383,
              1412,
              1384,
              1413,
              1385,
              1414,
              1386,
              1415,
              1387,
              1417,
              1388,
              1418,
              1389,
              1419,
              1390,
              1420,
              1391,
              1421,
              1392,
              1422,
              1393,
              1423,
              1394,
              1424,
              1395,
              1425,
              1396,
              1426,
              1397,
              1427,
              1398,
              1428,
              1399,
              1429,
              1400,
              1430,
              1431,
              1443,
              1432,
              1444,
              1433,
              1445,
              1434,
              1446,
              1435,
              1447,
              1436,
              1448,
              1437,
              1449,
              1438,
              1450,
              1439,
              1451,
              1440,
              1452,
              1441,
              1453,
              1442,
              1454]

version_3_1_forms = ['ivp_b5', 'fvp_b5', 'tvp_b5']

@update = Update.new(config: @config)

report_ids.compact.each do |report|

  response = @update.fetch_records(report)

  if response.nil?

    #binding.pry

  else

    in_json = JSON.parse(response)

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
          puts @update.update_record(id, current_field, "37", event_name)
        elsif type == "formver" && !version_3_1_forms.include?(form) #Set the Form Version to 3 for all except IVP B5, FVP B5, and TVP B5
          puts @update.update_record(id, current_field, "3", event_name)
        elsif type == "formver" && version_3_1_forms.include?(form) #Set the Form Version to 3.1 for IVP B5, FVP B5, TVP B5
          puts  @update.update_record(id, current_field, "3.1", event_name)
        end

      elsif !status.nil? && status == "0"
        puts "#{id} | #{event_name} | Status is 'Incomplete.'  This record should not be updated.".red
      else
        puts "#{id} | #{event_name} | No status.  This record should not be updated.".red
      end
    end
  end
end