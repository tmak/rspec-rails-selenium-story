dir = File.dirname(__FILE__)
ENV["RAILS_ENV"] = "selenium"
require File.expand_path(dir + "/../../config/environment")
require 'spec/rails/selenium_story'

Dir["#{dir}/steps/**/*.rb"].uniq.each do |file|
  require file
end