create_clock -period 50.000 -name can_clk -waveform {0.000 25.000} [get_ports can_clk]
create_clock -period 5.000 -name clk -waveform {0.000 2.500} [get_ports clk]
set_false_path -from [get_clocks can_clk] -to [get_clocks clk]
