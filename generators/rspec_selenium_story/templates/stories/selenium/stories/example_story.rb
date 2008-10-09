require File.expand_path(File.dirname(__FILE__) + "/../helper")

Story "Example", %{
  In order to know how to use this plugin
  As a rails hacker
  I want to have an example
}, :type => RailsSeleniumStory, :steps_for => [ :example ] do

  Scenario "Scenario 1" do
    Given "an example scenario"
    When "the example runs"
    Then "nothing happens"
  end
end