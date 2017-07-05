require 'test_helper'

class ThreadSafetyControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get thread_safety_index_url
    assert_response :success
  end

  test "should get simple" do
    get thread_safety_simple_url
    assert_response :success
  end

  test "should get infinite" do
    get thread_safety_infinite_url
    assert_response :success
  end

end
