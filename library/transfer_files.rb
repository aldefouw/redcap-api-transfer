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
    @export_data.data_cols.collect { |r| record_id(r)   }.uniq
  end

  def fields(id)
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

  def post_fields(id)
    fields(id).collect{|k, v| Curl::PostField.content(k.to_s, v)}
  end

  def get_record(id)
    Curl::Easy.http_post(@config.source_url, post_fields(id)) do |curl|
      success(curl, id)
      redirect(curl, id)
      missing(curl, id)
      failure(curl, id)
    end
  end

  def success(curl, id)
    curl.on_success { |r| puts "Success for #{id}!".green }
  end

  def redirect(curl, id)
    curl.on_redirect { |r| puts "Redirected for #{id}!".red }
  end

  def missing(curl, id)
    curl.on_missing { |r| puts "Missing for #{id}!".red }
  end

  def failure(curl, id)
    curl.on_failure { |r| puts "Failure for #{id}!".red }
  end

end