require "./src/predict"
require "benchmark"

private def tle_name_zero
  <<-TLE
  0 AO-51 [+]
  1 28375U 04025K   09105.66391970  .00000003  00000-0  13761-4 0  3643
  2 28375 098.0551 118.9086 0084159 315.8041 043.6444 14.40638450251959
  TLE
end

Benchmark.ips do |b|
  b.report("tle") { Predict::TLE.parse_three_line(tle_name_zero) }
end
