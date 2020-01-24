# Chart data maker
# This module is a function of create data to display chart.
# Requires CalculateEvm class.
#
module ChartDataMaker
  # Create data for display chart for chartjs.
  #
  # 1. basis EVM data for chart
  # 2. You chseck forecast option is on, add follows data
  # * BAC top line
  # * EAC top line
  # * forecast AC (forecast finish date)
  # * forecast EV (forecast finish date)
  #
  # @param [object] evm calculation EVN object
  # @return [hash] chart data
  def evm_chart_data_for_chartjs(evm)
    
    chart_minimum_date = [evm.pv.start_date, evm.ev.min_date, evm.ac.min_date].min
    chart_maximum_date = [evm.pv.due_date, evm.ev.max_date, evm.ac.max_date, evm.forecast_finish_date].max

    # overdue?
    if evm.pv_actual.state.equal?(:overdue)
      planned_value = evm.pv_actual.cumulative_pv.select { |date, _value| date < evm.basis_date }
    else
      planned_value = evm.pv_actual.cumulative_pv
    end
    if evm.pv_baseline.nil?
    else
      if evm.pv_baseline.state.equal?(:overdue)
        baseline_value = evm.pv_baseline.cumulative_pv.select { |date, _value| date < evm.basis_date }
      else
        baseline_value = evm.pv_baseline.cumulative_pv
      end
    end

    # forecast
    if evm.forecast
      # for chart
      # top line of BAC
      bac_top_line = {}
      bac_top_line[chart_minimum_date] = evm.bac
      bac_top_line[chart_maximum_date] = evm.bac
      # top line of EAC
      eac_top_line = {}
      eac_top_line[chart_minimum_date] = evm.eac
      eac_top_line[chart_maximum_date] = evm.eac
      # forecast line of AC
      actual_cost_forecast = {}
      actual_cost_forecast[evm.basis_date] = evm.today_ac
      actual_cost_forecast[evm.forecast_finish_date] = evm.eac
      # forecast line of EV
      earned_value_forecast = {}
      earned_value_forecast[evm.basis_date] = evm.today_ev
      earned_value_forecast[evm.forecast_finish_date] = evm.bac 
    end
    
    labels = []
    plotdata_planned_value = []
    plotdata_actual_cost = []
    plotdata_earned_value = []
    plotdata_baseline_value = []
    plotdata_planned_value_daily = []
    plotdata_bac_top_line = []
    plotdata_eac_top_line = []
    plotdata_actual_cost_forecast = []
    plotdata_earned_value_forecast = []

    for chart_date in chart_minimum_date..chart_maximum_date do
      labels << chart_date.to_time(:local).to_i * 1000
      plotdata_planned_value << planned_value[chart_date]
      plotdata_actual_cost << evm.ac.cumulative_ac[chart_date]
      plotdata_earned_value << evm.ev.cumulative_ev[chart_date]
      plotdata_baseline_value << baseline_value[chart_date] unless evm.pv_baseline.nil?
      plotdata_planned_value_daily << evm.pv.daily_pv[chart_date]
      plotdata_bac_top_line << bac_top_line[chart_date]
      plotdata_eac_top_line << eac_top_line[chart_date]
      plotdata_actual_cost_forecast << actual_cost_forecast[chart_date]
      plotdata_earned_value_forecast << earned_value_forecast[chart_date]
    end

    chart_data = {}
    chart_data[:labels] = labels
    chart_data[:pv] = plotdata_planned_value.to_s.delete("nil")
    chart_data[:ac] = plotdata_actual_cost.to_s.delete("nil")
    chart_data[:ev] = plotdata_earned_value.to_s.delete("nil")
    chart_data[:pv_daily] = plotdata_planned_value_daily.to_s.delete("nil")
    chart_data[:baseline] = plotdata_baseline_value.to_s.delete("nil") unless evm.pv_baseline.nil?
    chart_data[:bac] = plotdata_bac_top_line.to_s.delete("nil")
    chart_data[:eac] = plotdata_eac_top_line.to_s.delete("nil")
    chart_data[:ac_forecast] = plotdata_actual_cost_forecast.to_s.delete("nil")
    chart_data[:ev_forecast] = plotdata_earned_value_forecast.to_s.delete("nil")
    chart_data
  end
  # Create data for display performance chart.
  #
  # @return [hash] data for performance chart
  def performance_chart_data(evm)
    chart_data = {}
    new_ev = complement_evm_value evm.ev.cumulative_ev
    new_ac = complement_evm_value evm.ac.cumulative_ac
    new_pv = complement_evm_value evm.pv.cumulative_pv
    performance_min_date = [new_ev.keys.min,
                            new_ac.keys.min,
                            new_pv.keys.min].max
    performance_max_date = [new_ev.keys.max,
                            new_ac.keys.max,
                            new_pv.keys.max].min
    labels = []
    spi = []
    cpi = []
    cr = []
    (performance_min_date..performance_max_date).each do |date|
      labels << date.to_time(:local).to_i * 1000
      spi << (new_ev[date] / new_pv[date]).round(2)
      cpi << (new_ev[date] / new_ac[date]).round(2)
      cr << ((new_ev[date] / new_pv[date]).round(2) * (new_ev[date] / new_ac[date]).round(2)).round(2)
    end
    chart_data[:labels] = labels
    chart_data[:spi] = spi.to_s.delete("nil")
    chart_data[:cpi] = cpi.to_s.delete("nil")
    chart_data[:cr] = cr.to_s.delete("nil")
    chart_data
  end

  # Convert to chart. xAxis of Chart is time.
  #
  # @param [hash] data target issues of EVM
  # @return [array] EVM hash. Key:time, Value:EVM value
  def convert_to_chart(data)
    converted = Hash[data.map { |k, v| [k.to_time(:local).to_i * 1000, v] }]
    converted.to_a
  end

  # EVM value of Each date. for performance chart.
  #
  # @param [hash] evm_hash EVM hash
  # @return [hash] EVM value of All date
  def complement_evm_value(evm_hash)
    before_date = evm_hash.keys.min
    before_value = evm_hash[before_date]
    temp = {}
    evm_hash.each do |date, value|
      dif_days = (date - before_date - 1).to_i
      dif_value = (value - before_value) / dif_days
      if dif_days.positive?
        sum_value = 0.0
        (1..dif_days).each do |add_days|
          tmpdate = before_date + add_days
          sum_value += dif_value
          temp[tmpdate] = before_value + sum_value
        end
      end
      before_date = date
      before_value = value
      temp[date] = value
    end
    temp
  end
end