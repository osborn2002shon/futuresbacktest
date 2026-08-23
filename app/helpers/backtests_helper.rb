module BacktestsHelper
  CHART_WIDTH = 960
  CHART_HEIGHT = 320
  CHART_PADDING = 36

  def number_text(value, precision: 0)
    return "--" if value.nil?

    number_with_precision(value.to_f, precision: precision, delimiter: ",")
  end

  def point_text(value)
    number_text(value, precision: 1)
  end

  def signed_point_text(value)
    return "--" if value.nil?

    "#{value.negative? ? '' : '+'}#{point_text(value)}"
  end

  def percent_text(value)
    "#{number_with_precision(value.to_f, precision: 1)}%"
  end

  def time_text(value, include_date: true)
    return "--" if value.nil?

    value.strftime(include_date ? "%m/%d %H:%M" : "%H:%M")
  end

  def signal_text(signal)
    {
      "entry" => "進場",
      "exit" => "出場",
      "forced_exit" => "收盤"
    }[signal] || ""
  end

  def price_chart_data(bars)
    values = bars.flat_map { |bar| [bar[:close], bar[:entry_sma], bar[:exit_sma]] }.compact.map(&:to_f)

    return { empty: true } if values.empty?

    min_price = values.min
    max_price = values.max
    price_range = [max_price - min_price, 1.0].max
    pad = price_range * 0.08
    min_price -= pad
    max_price += pad

    {
      empty: false,
      close_points: points_for(bars, :close, min_price, max_price),
      entry_points: points_for(bars, :entry_sma, min_price, max_price),
      exit_points: points_for(bars, :exit_sma, min_price, max_price),
      markers: marker_points(bars, min_price, max_price),
      y_labels: y_labels(min_price, max_price)
    }
  end

  private

  def points_for(bars, key, min_price, max_price)
    bars.each_with_index.filter_map do |bar, index|
      value = bar[key]
      next if value.nil?

      "#{chart_x(index, bars.length)},#{chart_y(value.to_f, min_price, max_price)}"
    end.join(" ")
  end

  def marker_points(bars, min_price, max_price)
    bars.each_with_index.filter_map do |bar, index|
      next if bar[:signal].blank?

      {
        signal: bar[:signal],
        x: chart_x(index, bars.length),
        y: chart_y(bar[:close].to_f, min_price, max_price),
        label: signal_text(bar[:signal])
      }
    end
  end

  def y_labels(min_price, max_price)
    5.times.map do |step|
      ratio = step / 4.0
      price = max_price - ((max_price - min_price) * ratio)
      {
        y: CHART_PADDING + ((CHART_HEIGHT - (CHART_PADDING * 2)) * ratio),
        text: number_text(price, precision: 0)
      }
    end
  end

  def chart_x(index, total)
    usable_width = CHART_WIDTH - (CHART_PADDING * 2)
    denominator = [total - 1, 1].max

    (CHART_PADDING + (index.to_f / denominator * usable_width)).round(2)
  end

  def chart_y(value, min_price, max_price)
    usable_height = CHART_HEIGHT - (CHART_PADDING * 2)
    ratio = (value - min_price) / [max_price - min_price, 1.0].max

    (CHART_HEIGHT - CHART_PADDING - (ratio * usable_height)).round(2)
  end
end
