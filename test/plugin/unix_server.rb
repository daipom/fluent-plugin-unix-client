require "socket"
require "fileutils"

# When receiving data, this broadcasts the data to all connecting clients by UNIX domain socket.
class UnixBroadcastServer
  def initialize(path, use_log: false)
    @path = path
    @use_log = use_log
    @all_ids = []
    @data_handler = DataHandler.new(@all_ids)
    @cur_id = 0
  end

  def run
    if File.exist?(@path)
      log "Found existing '#{@path}'. Remove this file."
      File.unlink(@path)
    end
    FileUtils.mkdir_p(File.dirname(@path))

    Socket.unix_server_loop(@path) do |sock, addr|
      @cur_id += 1
      sock_id = @cur_id
      @all_ids.append(sock_id)

      log "#{sock} was newly opened. id: #{sock_id}"

      create_thread_to_receive(sock, sock_id)
      create_thread_to_send(sock, sock_id)
    rescue Errno::EPIPE => e
      log e.message
    end
  end

  private

  def close(sock, sock_id)
    log "#{sock_id}: closed."
    @all_ids.delete(sock_id)
    sock.close
  end

  def closed?(sock_id)
    !@all_ids.include?(sock_id)
  end

  def create_thread_to_receive(sock, sock_id)
    Thread.new do
      loop do
        record = sock.gets
        if record.nil?
          close(sock, sock_id)
          break
        end

        log "#{sock_id}: get #{record}"

        @data_handler.add_record_for_broadcast(sock_id, record)
      end
    end
  end

  def create_thread_to_send(sock, sock_id)
    Thread.new do
      loop do
        break if closed?(sock_id)

        records = @data_handler.get_records(sock_id)

        records.each do |record|
          log "#{sock_id}: write #{record}"
          sock.write(record)
        end

        Thread.pass
        sleep 0.5
      end
    end
  end

  def log(message)
    return unless @use_log
    p message
  end

  class DataHandler
    # Since this code is just for test, the locking process is not implemented.
    # Unexpected behavior may occur when processing in parallel.
    def initialize(all_ids)
      @all_ids = all_ids
      @buf_per_id = {}
    end

    def add_record_for_broadcast(from_id, record)
      @all_ids.each do |to_id|
        next if to_id == from_id
        add_record(to_id, record)
      end
    end

    def get_records(sock_id)
      records = @buf_per_id[sock_id]
      @buf_per_id[sock_id] = []
      return records.nil? ? [] : records
    end

    private

    def add_record(to_id, record)
      @buf_per_id[to_id] = [] if @buf_per_id[to_id].nil?
      @buf_per_id[to_id].append(record)
    end
  end
end
