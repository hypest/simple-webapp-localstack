require "test_helper"

class CountersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get counters_index_url
    assert_response :success
  end
end
