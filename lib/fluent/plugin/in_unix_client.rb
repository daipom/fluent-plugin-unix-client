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

module Fluent
  module Plugin
    class UnixClientInput < Fluent::Plugin::Input
      Fluent::Plugin.register_input("unix_client", self)

      helpers :thread

      desc 'Tag of output events.'
      config_param :tag, :string
      desc 'The path to Unix Domain Socket.'
      config_param :path, :string, default: nil

      def configure(conf)
        super
        @socket_handler = SocketHandler.new(@path, nil, log)
      end

      def start
        super
        thread_create(:in_unix_client, &method(:keep_receiving))
      end

      def keep_receiving
        while thread_current_running?
          begin
            record = @socket_handler.try_receive
            next if record.nil?
            router.emit(@tag, Fluent::Engine.now, record)
          rescue => e
            log.error "in_unix_client: error occurred. #{e}"
          end
        end
      ensure
        @socket_handler.try_close
      end
    end


    class SocketHandler
      MAX_SLEEPING_SECONDS = 600

      def initialize(path, parser, log)
        @path = path
        @parser = parser
        @log = log
        @socket = nil
      end

      def connected?
        !@socket.nil?
      end

      def try_receive
        block_until_succeed_to_open unless connected?
        raw_data = try_gets

        if raw_data.nil?
          @log&.warn "in_unix_client: server socket seems to be closed."
          try_close
          return nil
        end

        parse(raw_data)
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
      end

      def try_gets
        @socket.gets
      rescue => e
        @log&.error "in_unix_client: failed to receive data. #{e.message}"
        try_close
        block_until_succeed_to_open
        sleep 10
        retry
      end

      def block_until_succeed_to_open
        sleeping_seconds = 10

        loop do
          try_open
          break if connected?
          @log&.warn "in_unix_client: retry to open socket #{sleeping_seconds}s later."
          sleep sleeping_seconds
          sleeping_seconds = [2 * sleeping_seconds, MAX_SLEEPING_SECONDS].min
        end
      end

      def parse(record)
        return nil if record.nil?
        # TODO
        record
      end
    end
  end
end
