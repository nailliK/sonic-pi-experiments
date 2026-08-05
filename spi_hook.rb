require "delegate"
require "json"
require "socket"

tee = Class.new(SimpleDelegator) do
  def spi_start(port)
    @port = port
    @pending = SizedQueue.new(2048)
    @relay = Thread.new { relay }
    self
  end

  def spi_unwrap
    @relay&.kill
    __getobj__
  end

  def push(msg)
    __getobj__.push(msg)
    begin
      @pending.push(msg, true) if forward?(msg)
    rescue StandardError
      nil
    end
    self
  end

  alias << push
  alias enq push

  private

  def forward?(msg)
    msg.is_a?(Hash) &&
      %i[multi_message info incoming error syntax_error job exit].include?(msg[:type])
  end

  def relay
    socket = UDPSocket.new
    loop do
      msg = @pending.pop
      begin
        payload = render(msg)
        socket.send(JSON.generate(payload), 0, "127.0.0.1", @port) if payload
      rescue StandardError
        nil
      end
    end
  end

  def render(msg)
    case msg[:type]
    when :multi_message
      {
        t: "puts",
        job: msg[:jobid],
        thread: msg[:thread_name].to_s,
        lines: Array(msg[:val]).map { |entry| clip(Array(entry).last.to_s) }
      }
    when :info
      { t: "info", msg: clip(msg[:val].to_s) }
    when :incoming
      address = msg[:address].to_s
      { t: "cue", address: address, args: clip(msg[:args].to_s) } if address.start_with?("/")
    when :error, :syntax_error
      {
        t: "error",
        job: msg[:jobid],
        line: msg[:linenum],
        msg: clip(msg[:val].to_s),
        source: clip(msg[:error_line].to_s),
        trace: Array(msg[:backtrace])
          .map(&:to_s)
          .reject { |frame| frame.include?("/server/ruby/") }
          .first(5)
          .map { |frame| clip(frame) }
      }
    when :job
      { t: "job", job: msg[:jobid], action: msg[:action].to_s }
    when :exit
      { t: "exit" }
    end
  end

  def clip(str)
    str.length > 4096 ? "#{str[0, 4096]}…" : str
  end
end

previous = @msg_queue.respond_to?(:spi_unwrap) ? @msg_queue.spi_unwrap : @msg_queue
@msg_queue = tee.new(previous).spi_start(@spi_port || 4569)
