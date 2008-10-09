Dir[File.expand_path("#{File.dirname(__FILE__)}/stories/**/*.rb")].uniq.sort_by { rand }.each do |file|
  require file
end