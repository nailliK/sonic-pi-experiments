# frozen_string_literal: true

set :log_port, 4569 if get(:log_port).nil?

define :log_source do
  name = __current_thread_name.to_s
  name.empty? ? "main" : name.sub(/^live_loop_/, "")
end

define :log_enabled? do |source|
  only = get(:log_sources)
  only.nil? || only.map(&:to_s).include?(source)
end

define :emit do |event, fields = {}|
  source = log_source
  next unless log_enabled?(source)

  body = fields.map { |k, v| "#{k}=#{v}" }.join(" ")
  osc_send "127.0.0.1", get(:log_port), "/spi/event", "evt #{source} #{event} #{body}"
end

define :say do |msg|
  osc_send "127.0.0.1", get(:log_port), "/spi/log", msg.to_s
end
