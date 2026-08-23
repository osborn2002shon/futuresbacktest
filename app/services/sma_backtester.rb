require "bigdecimal"

class SmaBacktester
  STARTING_EQUITY = BigDecimal("0")

  attr_reader :bars, :entry_period, :exit_period

  def self.empty_result(entry_period, exit_period)
    {
      entry_period: entry_period,
      exit_period: exit_period,
      bars: [],
      trades: [],
      summary: empty_summary
    }
  end

  def self.empty_summary
    {
      total_trades: 0,
      winning_trades: 0,
      losing_trades: 0,
      win_rate: 0.0,
      total_points: BigDecimal("0"),
      average_points: BigDecimal("0"),
      best_trade_points: nil,
      worst_trade_points: nil,
      max_drawdown_points: BigDecimal("0")
    }
  end

  def initialize(bars:, entry_period:, exit_period:)
    @bars = bars
    @entry_period = entry_period
    @exit_period = exit_period
  end

  def call
    priced_bars = attach_smas
    trades = simulate(priced_bars)

    {
      entry_period: entry_period,
      exit_period: exit_period,
      bars: priced_bars,
      trades: trades,
      summary: summarize(trades)
    }
  end

  private

  def attach_smas
    closes = bars.map { |bar| bar[:close] }
    entry_smas = sma_series(closes, entry_period)
    exit_smas = sma_series(closes, exit_period)

    bars.each_with_index.map do |bar, index|
      bar.merge(
        entry_sma: entry_smas[index],
        exit_sma: exit_smas[index],
        signal: nil,
        closed_equity: STARTING_EQUITY
      )
    end
  end

  def sma_series(values, period)
    sum = BigDecimal("0")

    values.each_with_index.map do |value, index|
      sum += value
      sum -= values[index - period] if index >= period

      index >= period - 1 ? (sum / period) : nil
    end
  end

  def simulate(priced_bars)
    position = nil
    closed_equity = STARTING_EQUITY
    trades = []

    priced_bars.each_with_index do |bar, index|
      previous_bar = priced_bars[index - 1] if index.positive?

      if position.nil? && entry_signal?(previous_bar, bar)
        position = open_position(bar, index)
        bar[:signal] = "entry"
      elsif position && exit_signal?(previous_bar, bar)
        trade = close_position(position, bar, index, "SMA#{exit_period} 跌破出場")
        trades << trade
        closed_equity += trade[:points]
        bar[:signal] = "exit"
        position = nil
      end

      bar[:closed_equity] = closed_equity
      bar[:floating_equity] = closed_equity + floating_points(position, bar)
    end

    if position && priced_bars.any?
      final_bar = priced_bars.last
      trade = close_position(position, final_bar, priced_bars.length - 1, "24 小時資料結束平倉")
      trades << trade
      final_bar[:signal] = "forced_exit"
      final_bar[:closed_equity] += trade[:points]
      final_bar[:floating_equity] = final_bar[:closed_equity]
    end

    trades
  end

  def entry_signal?(previous_bar, current_bar)
    return false unless current_bar[:entry_sma]

    if previous_bar.nil? || previous_bar[:entry_sma].nil?
      current_bar[:close] > current_bar[:entry_sma]
    else
      previous_bar[:close] <= previous_bar[:entry_sma] && current_bar[:close] > current_bar[:entry_sma]
    end
  end

  def exit_signal?(previous_bar, current_bar)
    return false unless current_bar[:exit_sma]

    if previous_bar.nil? || previous_bar[:exit_sma].nil?
      current_bar[:close] < current_bar[:exit_sma]
    else
      previous_bar[:close] >= previous_bar[:exit_sma] && current_bar[:close] < current_bar[:exit_sma]
    end
  end

  def open_position(bar, index)
    {
      entry_index: index,
      entry_time: bar[:bar_start_taipei],
      entry_price: bar[:close],
      entry_sma: bar[:entry_sma]
    }
  end

  def close_position(position, bar, index, reason)
    points = bar[:close] - position[:entry_price]

    {
      entry_index: position[:entry_index],
      exit_index: index,
      entry_time: position[:entry_time],
      exit_time: bar[:bar_start_taipei],
      entry_price: position[:entry_price],
      exit_price: bar[:close],
      entry_sma: position[:entry_sma],
      exit_sma: bar[:exit_sma],
      bars_held: index - position[:entry_index],
      minutes_held: minutes_between(position[:entry_time], bar[:bar_start_taipei]),
      points: points,
      result: points.positive? ? "win" : "loss",
      reason: reason
    }
  end

  def floating_points(position, bar)
    return BigDecimal("0") unless position

    bar[:close] - position[:entry_price]
  end

  def minutes_between(start_time, end_time)
    return 0 if start_time.nil? || end_time.nil?

    ((end_time - start_time) / 60).round
  end

  def summarize(trades)
    return self.class.empty_summary if trades.empty?

    total_points = trades.sum(BigDecimal("0")) { |trade| trade[:points] }
    winning_trades = trades.count { |trade| trade[:points].positive? }
    losing_trades = trades.length - winning_trades

    {
      total_trades: trades.length,
      winning_trades: winning_trades,
      losing_trades: losing_trades,
      win_rate: (winning_trades.to_f / trades.length * 100).round(2),
      total_points: total_points,
      average_points: total_points / trades.length,
      best_trade_points: trades.map { |trade| trade[:points] }.max,
      worst_trade_points: trades.map { |trade| trade[:points] }.min,
      max_drawdown_points: max_drawdown(trades)
    }
  end

  def max_drawdown(trades)
    equity = STARTING_EQUITY
    peak = STARTING_EQUITY
    worst_drawdown = STARTING_EQUITY

    trades.each do |trade|
      equity += trade[:points]
      peak = equity if equity > peak
      drawdown = peak - equity
      worst_drawdown = drawdown if drawdown > worst_drawdown
    end

    worst_drawdown
  end
end
