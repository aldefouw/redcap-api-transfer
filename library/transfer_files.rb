require 'pry'
require 'csv'
require 'watir'
require 'logger'
require 'colorize'
require 'mechanize'
require 'parallel'
require 'highline'
require 'ruby-progressbar'

#Load Config
require "#{Dir.getwd}/library/config"

class TransferFiles

  include ActiveSupport::Inflector

  def initialize(**options)
    @base_dir = Dir.getwd
    options = options.merge(base_dir: @base_dir)

    puts 'Loading Configuration ... '
    @config = Config.new(options)

    options = options.merge(config: @config)

    puts 'Loading Export Data ... '
    @export_data = ExportData.new(config: @config)

  end

  def run

    binding.pry

  end

  private


end