steps_for :login_example do
  Given "a user with an account is viewing the site's index page" do
    # You have no model factory?
    # Shame on you... ;-)
    # 
    # ModelFactory.create_user(:login => "tester")
    selenium.open '/'
    selenium.check_for_exception
  end

  When "the user clicks on the 'Log in' link" do
    selenium.click "link=Log in"
    selenium.wait_for_page_to_load 5000
    selenium.check_for_exception
  end

  Then "the user will be presented with the login form" do
    selenium.should have_text_present("Login")
    selenium.should have_element_present("//form[@id='login_form']")
  end

  When "the user submits the login form with valid credentials" do
    selenium.type "login", "tester"
    selenium.check_for_exception
    selenium.type "password", "testerpass"
    selenium.check_for_exception
    selenium.click "//input[@value='Login']"
    selenium.wait_for_page_to_load 5000
    selenium.check_for_exception
  end

  Then "the user will see a notice" do
    selenium.should have_text_present("Successfully logged in.")
  end

  Then "the user will see his dashboard" do
    selenium.location.should == '/dashboard'
  end
end