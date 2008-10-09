
class RspecSeleniumStoryGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.file      'config/environments/selenium.rb',              'config/environments/selenium.rb'
      m.directory 'stories/selenium'
      m.file      'stories/selenium/all.rb',                      'stories/selenium/all.rb'
      m.file      'stories/selenium/helper.rb',                   'stories/selenium/helper.rb'
      m.directory 'stories/selenium/steps'
      m.file      'stories/selenium/steps/example_steps.rb',      'stories/selenium/steps/example_steps.rb'
      m.directory 'stories/selenium/stories'
      m.file      'stories/selenium/stories/example_story.rb',    'stories/selenium/stories/example_story.rb'
    end
  end

protected
  def banner
    "Usage: #{$0} rspec_selenium_story"
  end
end