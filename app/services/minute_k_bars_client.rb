require "bigdecimal"
require "json"
require "net/http"
require "time"
require "uri"

class MinuteKBarsClient
  DEFAULT_ENDPOINT = "https://futuresmonitor.cjhwork.com/api/minute-k-bars"

  RequestError = Class.new(StandardError)

  def initialize(endpoint: ENV.fetch("MINUTE_K_BARS_API_URL", DEFAULT_ENDPOINT))
    @endpoint = endpoint
  end

  def fetch
    uri = URI(@endpoint)
    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: 5,
      read_timeout: 20
    ) do |http|
      http.get(uri.request_uri, "Accept" => "application/json")
    end

    raise RequestError, "API 回應失敗：HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    normalize(JSON.parse(response.body))
  rescue JSON::ParserError
    raise RequestError, "API 回傳內容不是有效 JSON"
  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout => e
    raise RequestError, "無法連線到分 K API：#{e.message}"
  rescue URI::InvalidURIError => e
    raise RequestError, "API URL 無效：#{e.message}"
  end

  private

  def normalize(payload)
    bars = Array(payload["bars"]).filter_map do |bar|
      normalize_bar(bar)
    end.sort_by { |bar| bar[:bar_start_taipei] || Time.at(0) }

    {
      connected: payload["isConnected"],
      message: payload["message"],
      symbol: payload["symbol"],
      interval_minutes: payload["intervalMinutes"].to_i,
      generated_at_taipei: parse_time(payload["generatedAtTaipei"]),
      from_taipei: parse_time(payload["fromTaipei"]),
      to_taipei: parse_time(payload["toTaipei"]),
      bars: bars
    }
  end

  def normalize_bar(bar)
    start_time = parse_time(bar["barStartTaipei"])
    close = decimal(bar["close"])

    return if start_time.nil? || close.nil?

    {
      bar_start_taipei: start_time,
      bar_end_taipei: parse_time(bar["barEndTaipei"]),
      open: decimal(bar["open"]),
      high: decimal(bar["high"]),
      low: decimal(bar["low"]),
      close: close,
      source_count: bar["sourceCount"].to_i,
      updated_at_taipei: parse_time(bar["updatedAtTaipei"])
    }
  end

  def parse_time(value)
    return if value.blank?

    Time.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def decimal(value)
    return if value.nil?

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end
end
