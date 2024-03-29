#
# Copyright 2021- daipom
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/input"
require 'socket'
require "json"

module Fluent
  module Plugin
    class UnixClientInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("unix_client", self)

      helpers :thread, :parser

      desc 'Tag of output events.'
      config_param :tag, :string
      desc 'The path to Unix Domain Socket.'
      config_param :path, :string
      desc 'The payload is read up to this character.'
      config_param :delimiter, :string, default: "\n"
      desc "When recieved JSON data splitted by the delimiter is not completed, like '[{...},'," \
           " trim '[', ']' and ',' characters to format."
      config_param :format_json, :bool, default: false

      def configure(conf)
        super
        @parser = parser_create
        @socket_handler = SocketHandler.new(
          @path,
          delimiter: @delimiter,
          format_json: @format_json,
          log: log,
        )
      end

      def start
        super
        thread_create(:in_unix_client, &method(:keep_receiving))
      end

      def keep_receiving
        while thread_current_running?
          begin
            receive_and_emit
          rescue => e
            log.error "in_unix_client: error occurred. #{e}"
            sleep 3
          end
        end
      ensure
        @socket_handler.try_close
      end

      def receive_and_emit
        raw_records = @socket_handler.try_receive
        return if raw_records.nil? || raw_records.empty?

        raw_records.each do |raw_record|
          @parser.parse(raw_record) do |time, record|
            emit_one_parsed(time, record)
          end
        end
      end

      def emit_one_parsed(time, record)
        case record
        when Array
          es = Fluent::MultiEventStream.new
          record.each do |e|
            es.add(time, e)
          end
          router.emit_stream(@tag, es)
        else
          router.emit(@tag, time, record)
        end
      end
    end


    class SocketHandler
      MAX_LENGTH_RECEIVE_ONCE = 10000

      def initialize(path, delimiter: "\n", format_json: false, log: nil)
        @path = path
        @log = log
        @socket = nil
        @buf = Buffer.new(delimiter, format_json: format_json)
      end

      def connected?
        !@socket.nil?
      end

      def try_receive(timeout: 1)
        unless connected?
          try_open
          return []
        end
        return [] unless exist_data?(timeout)

        records, has_closed = try_get_records

        if has_closed
          @log&.warn "in_unix_client: server socket seems to be closed."
          try_close
          return []
        end

        records
      end

      def try_close
        @socket&.close
      rescue => e
        @log&.error "in_unix_client: failed to close socket. #{e.message}"
      ensure
        @socket = nil
      end

      private

      def try_open
        @socket = UNIXSocket.open(@path)
        @log&.info "in_unix_client: opened socket: #{@path}."
      rescue => e
        @log&.warn "in_unix_client: failed to open socket: #{@path}, due to: #{e.message}"
        @socket = nil
        sleep 3
      end

      def exist_data?(timeout)
        return true if IO::select([@socket], nil, nil, timeout)
        false
      end

      def try_get_records
        msg, * = @socket.recvmsg_nonblock(MAX_LENGTH_RECEIVE_ONCE)
        has_closed = msg.empty?
        return [], has_closed if has_closed

        @buf << msg
        records = @buf.extract_records
        return records, has_closed
      rescue IO::WaitReadable => e
        @log&.debug "in_unix_client: there were no data though the socket was recognized readable by IO::select. #{e.message}"
        sleep 3
      rescue => e
        @log&.error "in_unix_client: failed to receive data. #{e.message}"
        sleep 3
      end
    end


    class Buffer
      def initialize(delimiter, format_json: false)
        @buf = ""
        @delimiter = delimiter
        @format_json = format_json
      end

      def add(data)
        @buf << data
      end

      def <<(data)
        add(data)
      end

      def extract_records
        records = []

        pos_read = 0
        while pos_next_delimiter = @buf.index(@delimiter, pos_read)
          fixed = fix_format(@buf[pos_read...pos_next_delimiter])
          records << fixed unless fixed.empty?
          pos_read = pos_next_delimiter + @delimiter.size
        end

        @buf.slice!(0, pos_read) if pos_read > 0

        records
      end

      private

      def fix_format(record)
        return record if record.empty?
        return record unless @format_json

        fix_uncompleted_json(record)
      end

      def fix_uncompleted_json(record)
        return record if is_correct_json(record)

        # Assume uncompleted JSON such as "[{...},", "{...},", or "{...}]"

        if record[0] == "["
          record.slice!(0)
          return record if record.empty?
        end

        if record[-1] == "," || record[-1] == "]"
          record.slice!(-1)
          return record if record.empty?
        end

        record
      end

      def is_correct_json(record)
        # Just to check the format
        JSON.parse(record)
        return true
      rescue JSON::ParserError
        return false
      end
    end
  end
end
