require File.expand_path(File.dirname(__FILE__) + "/../helper")

Story "Login example", %{
  In order to use my rails application
  As a user
  I want to login
}, :type => RailsSeleniumStory, :steps_for => [ :login_example ] do

  Scenario "Activated user with valid credentials" do
    Given "a user with an account is viewing the site's index page"
    When "the user clicks on the 'Log in' link"
    Then "the user will be presented with the login form"

    When "the user submits the login form with valid credentials"
    Then "the user will see a notice"
    And "the user will see his dashboard"
  end
end