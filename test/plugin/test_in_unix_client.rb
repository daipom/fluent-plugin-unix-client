require "socket"
require "json"
require "time"
require "helper"
require "fluent/test/driver/input"
require "fluent/plugin/in_unix_client.rb"
require_relative "./unix_server.rb"

class UnixClientInputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
    @server_thread = nil
  end

  def teardown
    stop_server
    FileUtils.rm_rf(TMP_DIR)
  end

  TMP_DIR = File.dirname(__FILE__) + "/../tmp/socket"

  BASE_CONFIG = %[
    @type unix_client
    tag unix_client
    path #{TMP_DIR}/socket.sock
  ]

  DEFAULT_MSG = "Hello world."

  def test_configure
    d = create_driver(config_with_json_parser)
    assert_equal "unix_client", d.instance.tag
    assert_equal "#{TMP_DIR}/socket.sock", d.instance.path
  end

  def test_receive_json
    d = create_driver(config_with_json_parser)
    path = d.instance.path

    start_server(path)

    cur_time = Time.now.to_i

    d.run(expect_records: 1, timeout: 10) do
      sleep 1
      send_json(path, time: cur_time)
    end

    assert_equal 1, d.events.length

    d.events.each do |tag, time, record|
      assert_equal "unix_client", tag
      assert_equal cur_time, time
      assert_equal DEFAULT_MSG, record["msg"]
    end
  end

  def test_receive_json_with_custom_delimiter_newline
    d = create_driver(config_with_json_parser_and_delimiter('\n'))
    path = d.instance.path

    start_server(path)

    cur_time = Time.now.to_i

    d.run(expect_records: 1, timeout: 10) do
      sleep 1
      send_json(path, time: cur_time, delimiter: "\n")
    end

    assert_equal 1, d.events.length

    d.events.each do |tag, time, record|
      assert_equal "unix_client", tag
      assert_equal cur_time, time
      assert_equal DEFAULT_MSG, record["msg"]
    end
  end

  def test_receive_json_with_custom_delimiter_tab
    d = create_driver(config_with_json_parser_and_delimiter('\t'))
    path = d.instance.path

    start_server(path)

    cur_time = Time.now.to_i

    d.run(expect_records: 1, timeout: 10) do
      sleep 1
      send_json(path, time: cur_time, delimiter: "\t")
    end

    assert_equal 1, d.events.length

    d.events.each do |tag, time, record|
      assert_equal "unix_client", tag
      assert_equal cur_time, time
      assert_equal DEFAULT_MSG, record["msg"]
    end
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Input.new(Fluent::Plugin::UnixClientInput).configure(conf)
  end

  def config_with_json_parser
    BASE_CONFIG + %!
      <parse>
        @type json
      </parse>
    !
  end

  def config_with_json_parser_and_delimiter(delimiter)
    BASE_CONFIG + %[
      delimiter \"#{delimiter}\"
    ] + %!
      <parse>
        @type json
      </parse>
    !
  end

  def start_server(path)
    @server_thread = Thread.new do
      server = UnixBroadcastServer.new(path)
      server.run
    end
    sleep 1
  end

  def stop_server
    if @server_thread
      @server_thread.kill if @server_thread
      @server_thread.join
      @server_thread = nil
    end
  end

  def send_json(path, time: nil, msg: DEFAULT_MSG, delimiter: "\n")
    msg = JSON.generate(
      {
        "time" => time.nil? ? Time.now.to_i : time,
        "msg" => msg
      }
    )
    UNIXSocket.open(path) do |sock|
      sock.write(msg)
      sock.write(delimiter)
    end
  end
end
