class BacktestsController < ApplicationController
  DEFAULT_ENTRY_MA = 60
  DEFAULT_EXIT_MA = 20
  PERIOD_RANGE = 2..720

  def show
    @entry_period = period_param(:entry_ma, DEFAULT_ENTRY_MA)
    @exit_period = period_param(:exit_ma, DEFAULT_EXIT_MA)
    
    @market_data = MinuteKBarsClient.new.fetch
    @result = SmaBacktester.new(
      bars: @market_data[:bars],
      entry_period: @entry_period,
      exit_period: @exit_period
    ).call
  rescue MinuteKBarsClient::RequestError => e
    @error_message = e.message
    @market_data = nil
    @result = SmaBacktester.empty_result(@entry_period, @exit_period)
  end

  private

  def period_param(name, default)
    value = params[name].to_i
    PERIOD_RANGE.cover?(value) ? value : default
  end

end
