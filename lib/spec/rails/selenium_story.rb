require 'spec/rails/story_adapter'
require 'selenium'
require 'net/http'

module Selenium
  class SeleniumDriver
    # Alias some more ruby-like methods, to make it play better with rspec matchers.
    alias_method :original_method_missing, :method_missing
    def method_missing method_name, *args
      if method_name.to_s =~ /^has_.*\?$/
        real_method = method_name.to_s.sub(/has_(.*)\?$/, 'is_\1')
        if respond_to? real_method
          return send(real_method, args)
        end
      elsif respond_to?(real_method = "get_" + method_name.to_s)
        return send(real_method)
      end
      return original_method_missing(method_name, args)
    end

    def location
      get_location.sub(/https?\:\/\/localhost(\:\d{4,5})?\//, '/')
    end

    def reset_cookie(cookie_name)
        get_eval("window.document.cookie = '#{cookie_name}=;expires=Thu, 01-Jan-1970 00:00:01 GMT; path=/';")
    end

    def check_for_exception
      if title.include? "Exception caught"
        raise "A server exception occured"
      end
    end
  end
end

class RailsSeleniumStory < RailsStory
  @@browser = nil
  self.use_transactional_fixtures = false

  def self.start_browser_session
    unless @@browser
      browser_start_command ="*firefox"
      browser_start_command = ENV["SELENIUM_BROWSER"] if ENV["SELENIUM_BROWSER"]

      @@browser = Selenium::SeleniumDriver.new("localhost", 8989,
                                                browser_start_command,
                                                "http://localhost:8787",
                                                15000)
      @@browser.start
    end
  end

  def self.stop_browser_session
    if @@browser
      @@browser.stop
      @@browser = nil
    end
  end

  def self.reset_browser_cookies
    if @@browser
      ["auth_token", Rails.configuration.action_controller.session[:session_key]].each do |cookie_name|
        @@browser.reset_cookie(cookie_name)
      end
    end
  end

  def self.browser
    @@browser
  end

  def browser
    self.class.browser
  end

  def selenium
    browser
  end
end

class SeleniumListener
  include Singleton

  def method_missing method_name, *args
  end

  def run_started(*args)
    @start_time = Time.now
    start_x_server if ENV["SELENIUM_BACKGROUND"] == "1"
    start_selenium_server
    RailsSeleniumStory.start_browser_session
  end

  def run_ended(*args)
    RailsSeleniumStory.stop_browser_session
    stop_selenium_server
    stop_x_server if ENV["SELENIUM_BACKGROUND"] == "1"
    puts
    puts "Finished in #{Time.now - @start_time} seconds"
  end

  def story_started(title, narrative)
    @current_story_title = title
  end

  def scenario_started(*args)
    prepare_test_db
    start_test_server
    RailsSeleniumStory.reset_browser_cookies
  end

  def scenario_succeeded(*args)
    stop_test_server
  end

  def scenario_failed(title, name, e)
    RailsSeleniumStory.browser.capture_screenshot("#{screenshots_dir}/scenario-#{@current_story_title.gsub(/[ \/\\-]/, "_")}-#{name.gsub(/[ \/\\-]/, "_")}-screenshot.png")
    scenario_succeeded(title, name, e)
  end

  alias :scenario_pending :scenario_failed

protected
  def screenshots_dir
    unless @screenshots_dir
      @screenshots_dir = FileUtils.mkdir_p("#{RAILS_ROOT}/tmp/selenium/#{@start_time.strftime("%Y%m%d%H%M%S")}/screenshots")
      FileUtils.mkdir_p(@screenshots_dir)
    end
    @screenshots_dir
  end

  def temp_db_dir
    unless @temp_db_dir
      @temp_db_dir = FileUtils.mkdir_p("#{RAILS_ROOT}/tmp/selenium/#{@start_time.strftime("%Y%m%d%H%M%S")}/temp_db")
      FileUtils.mkdir_p(@temp_db_dir)
    end
    @temp_db_dir
  end

  def prepare_test_db
    unless @temp_test_db_path
      @temp_test_db_path = "#{temp_db_dir}/selenium-db.sqlite3"
      @test_db_path = File.expand_path(ActiveRecord::Base.configurations[ENV["RAILS_ENV"]]["database"], RAILS_ROOT)
    end

    unless File.exist?(@temp_test_db_path)
     `rake db:reset RAILS_ENV=selenium`
      FileUtils.copy @test_db_path, @temp_test_db_path
    else
      FileUtils.copy @temp_test_db_path, @test_db_path
    end
    ActiveRecord::Base.clear_active_connections!
  end

  def start_x_server
    pid = fork do
      # Since we can't use shell redirects without screwing
      # up the pid, we'll reopen stdin and stdout instead
      # to get the same effect.
      [STDOUT,STDERR].each {|f| f.reopen '/dev/null', 'w' }
      exec "Xvfb :1 -ac -screen 0 1600x1200x24"
      exit! 127
    end
    File.open X_SERVER_PID_FILE, 'w' do |f|
      f.puts pid
    end

    sleep 1.5
  end

  def stop_x_server
    if File.exist? X_SERVER_PID_FILE
      pid = File.read(X_SERVER_PID_FILE).to_i
      Process.kill 'TERM', pid
      FileUtils.rm X_SERVER_PID_FILE
    end
  end

  def start_selenium_server
    fork do
      f = File.open(SELENIUM_SERVER_OUTPUT_FILE, 'a')
      command = "selenium -port #{SELENIUM_SERVER_PORT}"
      command = "bash -c \"DISPLAY=:1 #{command}\"" if ENV["SELENIUM_BACKGROUND"] == "1"
      IO.popen(command).readlines.each { |p| f.puts p }
      f.close
    end

    ticker = 0
    while ticker < 10
      begin
        sleep 0.5
        Net::HTTP.get('localhost', '/', SELENIUM_SERVER_PORT)
        ticker = 10
      rescue
        ticker += 1
      end
    end
  end

  def stop_selenium_server
    Net::HTTP.get('localhost', '/selenium-server/driver/?cmd=shutDown', SELENIUM_SERVER_PORT)
  end

  def start_test_server
    `ruby script/server -e selenium -p #{TEST_SERVER_PORT} -d`

    ticker = 0
    while ticker < 10
      begin
        sleep 0.5
        Net::HTTP.get('localhost', '/', TEST_SERVER_PORT)
        ticker = 10
      rescue
        ticker += 1
      end
    end
  end

  def stop_test_server
    if File.exist? TEST_SERVER_PID_FILE
      pid = File.read(TEST_SERVER_PID_FILE).to_i
      Process.kill 'TERM', pid
    else
      puts "#{TEST_SERVER_PID_FILE} not found"
    end
  end

  X_SERVER_PID_FILE = 'tmp/pids/xserver.pid'
  SELENIUM_SERVER_PORT = 8989
  SELENIUM_SERVER_OUTPUT_FILE = 'log/selenium.log'
  TEST_SERVER_PORT = 8787
  TEST_SERVER_PID_FILE = "#{RAILS_ROOT}/tmp/pids/mongrel.pid"
end

class ActiveRecordSafetyListener
  include Singleton

  def scenario_started(*args)
    # override this so we don't use transactions
  end

  def scenario_succeeded(*args)
    # override this so we don't use transactions
  end

  alias :scenario_pending :scenario_succeeded
  alias :scenario_failed :scenario_succeeded
end

$selenium_listener_added = false unless $selenium_listener_added
unless $selenium_listener_added
  Spec::Story::Runner.register_listener SeleniumListener.instance
  $selenium_listener_added = true
end