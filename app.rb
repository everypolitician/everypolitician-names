require 'bundler/setup'
Bundler.require
Dotenv.load

require 'open-uri'
require 'json'
require 'pry'
require 'active_support/core_ext'
require 'fileutils'

class NameCsvGenerator
  include Sidekiq::Worker
  include Everypoliticianbot::Github

  def perform
    with_git_repo('everypolitician/everypolitician-names', branch: 'gh-pages', message: 'Update names.csv') do

      countries = JSON.parse(open('https://raw.githubusercontent.com/everypolitician/everypolitician-data/master/countries.json').read, symbolize_names: true)

      CSV.open('names.csv','w') do |output_csv|
        headers = [:id, :name, :country, :legislature]
        output_csv << headers

        countries.each do |c|
          c[:legislatures].each do |l|
            legislature_namefile = File.join(File.dirname(l[:popolo]), 'names.csv')
            warn legislature_namefile
            CSV.foreach(legislature_namefile, headers: true) { |row| 
              row['country'] = c[:slug]
              row['legislature'] = l[:slug]
              output_csv << row.values_at(*headers) 
            }
          end
        end
        
      end
    end
  end
end

post '/' do
  NameCsvGenerator.perform_async
  'ok'
end

get '/' do
  'hello world'
end
