@api @data @api_data
Feature: Create a data bag via the REST API
  In order to create data bags programatically 
  As a Devleoper
  I want to create data bags via the REST API
  
  Scenario: Create a new data bag 
    Given a 'registration' named 'bobo' exists
      And a 'data_bag' named 'users'
     When I authenticate as 'bobo'
      And I 'POST' the 'data_bag' to the path '/data' 
      And the inflated responses key 'uri' should match '^http://.+/data/users$'

  Scenario: Create a data bag that already exists
    Given a 'registration' named 'bobo' exists
      And a 'data_bag' named 'users'
     When I authenticate as 'bobo'
      And I 'POST' the 'data_bag' to the path '/data' 
      And I 'POST' the 'data_bag' to the path '/data' 
     Then I should get a '403 "Forbidden"' exception

  Scenario: Create a new data bag without authenticating
    Given a 'data_bag' named 'webserver'
     When I 'POST' the 'data_bag' to the path '/data' 
     Then I should get a '401 "Unauthorized"' exception

  Scenario: Create a new data bag as a non-admin
    Given a 'registration' named 'not_admin' exists
      And a 'data_bag' named 'users'
     When I 'POST' the 'data_bag' to the path '/data' 
     Then I should get a '401 "Unauthorized"' exception

