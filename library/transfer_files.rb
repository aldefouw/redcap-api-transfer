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

#Load Config
require "#{Dir.getwd}/library/config"
require "#{Dir.getwd}/library/export_data"

class TransferFiles

  def initialize(**options)
    @base_dir = Dir.getwd
    options = options.merge(base_dir: @base_dir)

    puts 'Loading Configuration ... '
    @config = Config.new(options)

    options = options.merge(config: @config)

    puts 'Loading Export Data ... '
    @export_data = ExportData.new(options)
  end

  def run
    unique_record_ids.each { |id| get_record(id) }
  end

  private

  def record_id(row)
    row.first[1]
  end

  def unique_record_ids
    @export_data.data_cols.map { |r| record_id(r)   }.uniq
  end

  def s_fields(id)
    {
        :token => @config.source_token,
        :content => 'record',
        :format => 'json',
        :type => 'raw',
        :records => id,
        :rawOrLabel => 'raw',
        :rawOrLabelHeaders => 'raw',
        :exportCheckboxLabel => 'true',
        :exportSurveyFields => 'true',
        :exportDataAccessGroups => 'false',
        :returnFormat => 'json'
    }
  end

  def source_fields(id)
    s_fields(id).map{|k, v| Curl::PostField.content(k.to_s, v)}
  end

  def get_record(id)
    Curl::Easy.http_post(@config.source_url, source_fields(id)) do |curl|
      success(curl, id)
      redirect(curl, id)
      missing(curl, id)
      failure(curl, id)
      complete(curl, id)
    end
  end

  def d_fields(source_data)
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

  def destination_fields(source_data)
    d_fields(source_data).map{|k, v| Curl::PostField.content(k.to_s, v)}
  end

  def write_record_to_destination(id, response)
    fields = {
        :token => @config.destination_token,
        :content => 'record',
        :format => 'json',
        :type => 'flat',
        :data => response.body_str,
    }

    ch = Curl::Easy.http_post('http://localhost:8054/redcap_v7.4.5/api/', fields.collect{|k, v| Curl::PostField.content(k.to_s, v)})
    puts ch.body_str
    #
    #
    #
    #
    # Curl::Easy.http_post(@config.destination_url, destination_fields(response.body_str)) do |curl|
    #   curl.on_success do |r|
    #
    #     binding.pry
    #
    #     puts "Successfully created #{id}!".green
    #   end
    #   redirect(curl, id)
    #   missing(curl, id)
    #   failure(curl, id)
    #   complete(curl, id)
    # end

  end

  def success(curl, id)
    curl.on_success do |r|
      puts "Successfully fetched #{id}!".green
      write_record_to_destination(id, r)
    end
  end

  def redirect(curl, id)
    curl.on_redirect do |r|
      puts "Redirected for #{id}!".red
    end
  end

  def missing(curl, id)
    curl.on_missing { |r| puts "Missing for #{id}!".red }
  end

  def failure(curl, id)
    curl.on_failure { |r| puts "Failure for #{id}!".red }
  end

  def complete(curl, id)
    curl.on_complete { |r|  }
  end

end