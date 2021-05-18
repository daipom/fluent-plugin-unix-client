require "helper"
require "fluent/plugin/in_unix_client.rb"

class UnixClientInputTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  test "failure" do
    flunk
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::UnixClientInput).configure(conf)
  end
end
