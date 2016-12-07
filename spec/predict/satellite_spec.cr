require "../spec_helper"

private def compare_satrec(expected, actual, margin)
  {% for var in Predict::SGP4::Elset.instance_vars %}
    diff = (expected.{{var}} - actual.{{var}}).abs
    if diff > margin
      puts
      puts "{{var}}"
      puts "  expected: #{expected.{{var}}.inspect}"
      puts "  actual  : #{actual.{{var}}.inspect}"
      puts "  diff    : #{diff} (> #{margin})"
    end
  {% end %}

  {% for var in Predict::SGP4::Elset.instance_vars %}
    actual.{{var}}.should be_close(expected.{{var}}, margin)
  {% end %}
end

private def verify_init(tle)
  line1, line2 = tle.split('\n')

  Predict::SGP4::GravConstType.values.each do |grav|
    tle_ = Predict::TLE.parse_two_line(tle, "TestSat 1")
    satellite = Predict::Satellite.new(tle_, grav)

    line1_arry = uninitialized UInt8[130]
    line1_arry.to_slice.copy_from(line1.to_slice)
    line2_arry = uninitialized UInt8[130]
    line2_arry.to_slice.copy_from(line2.to_slice)

    nullptr = Pointer(LibC::Double).null
    expected_satrec = Predict::SGP4::Elset.new
    double = 0.0
    SGP4.twoline2rv(line1_arry, line2_arry, 'c'.ord.to_u8, 0_u8, 'i'.ord.to_u8, grav, pointerof(double), pointerof(double), pointerof(double), pointerof(expected_satrec))

    compare_satrec(expected_satrec, satellite.satrec, 1.0e-8)
  end
end

GROUND_STATION = Predict::LatLongAlt.from_degrees(52.4670, -2.022, 200.0)

describe Predict::Satellite do
  it "initializes the elset correctly" do
    verify_init <<-TLE
      1 28375U 04025K   09105.66391970  .00000003  00000-0  13761-4 0  3643
      2 28375 098.0551 118.9086 0084159 315.8041 043.6444 14.40638450251959
      TLE

    verify_init <<-TLE
      1 00005U 58002B   00179.78495062  .00000023  00000-0  28098-4 0  4753
      2 00005  34.2682 348.7242 1859667 331.7664  19.3264 10.82419157413667
      TLE

    verify_init <<-TLE
      1 06251U 62025E   06176.82412014  .00008885  00000-0  12808-3 0  3985
      2 06251  58.0579  54.0425 0030035 139.1568 221.1854 15.56387291  6774
      TLE

    verify_init <<-TLE
      1 16925U 86065D   06151.67415771  .02550794 -30915-6  18784-3 0  4486
      2 16925  62.0906 295.0239 5596327 245.1593  47.9690  4.88511875148616
      TLE

    verify_init <<-TLE
      1 21897U 92011A   06176.02341244 -.00001273  00000-0 -13525-3 0  3044
      2 21897  62.1749 198.0096 7421690 253.0462  20.1561  2.01269994104880
      TLE

    verify_init <<-TLE
      1 22312U 93002D   06094.46235912  .99999999  81888-5  49949-3 0  3953
      2 22312  62.1486  77.4698 0308723 267.9229  88.7392 15.95744531 98783
      TLE
  end

  it "predicts LEO satellites" do
    tle = Predict::TLE.parse_three_line <<-TLE
      AO-51 [+]
      1 28375U 04025K   09105.66391970  .00000003  00000-0  13761-4 0  3643
      2 28375 098.0551 118.9086 0084159 315.8041 043.6444 14.40638450251959
      TLE
    time = Time.new(2009, 4, 17, 6, 57, 32)

    satellite = Predict::Satellite.new(tle)
    satellite_position, _ = satellite.predict(time)

    lat_long_alt = satellite_position.to_lat_long_alt(time)
    lat_long_alt.latitude.should be_close(0.5648232, 0.5e-7)
    lat_long_alt.longitude.should be_close(-0.0762018, 0.5e-7)
    lat_long_alt.altitude.should be_close(818.1371913, 0.5e-7)

    look_angle = GROUND_STATION.look_at(satellite_position, time)
    look_angle.azimuth.should be_close(3.2421950, 0.5e-7)
    look_angle.elevation.should be_close(0.1511579, 0.5e-7)
    look_angle.range.should be_close(2506.0973801, 0.5e-7)
  end

  it "predicts weather satellites" do
    tle = Predict::TLE.parse_three_line <<-TLE
      TIROS N [P]
      1 11060U 78096A   09359.84164805 -.00000019  00000-0  13276-4 0  3673
      2 11060  98.9548 331.5509 0010393 187.3222 172.7804 14.17491792826101
      TLE
    time = Time.new(2009, 12, 26, 0, 0, 0)

    satellite = Predict::Satellite.new(tle)
    satellite_position, _ = satellite.predict(time)

    lat_long_alt = satellite_position.to_lat_long_alt(time)
    lat_long_alt.latitude.should be_close(1.4098576, 0.5e-7)
    lat_long_alt.longitude.should be_close(2.8305378, 0.5e-7)
    lat_long_alt.altitude.should be_close(848.4314995, 0.5e-7)

    look_angle = GROUND_STATION.look_at(satellite_position, time)
    look_angle.azimuth.should be_close(0.0602822, 0.5e-7)
    look_angle.elevation.should be_close(-0.2617648, 0.5e-7)
    look_angle.range.should be_close(5433.9602254, 0.5e-7)
  end

  it "predicts deorbiting satellites" do
    tle = Predict::TLE.parse_three_line <<-TLE
      COSMOS 2421 DEB
      1 33139U 06026MX  09359.84164805  .10408321  74078-5  34039-2 0  6397
      2 33139 064.8768 254.5588 0010700 285.2081 074.8503 16.45000000 91116
      TLE
    time = Time.new(2009, 12, 26, 0, 0, 0)

    satellite = Predict::Satellite.new(tle)
    satellite_position, _ = satellite.predict(time)

    lat_long_alt = satellite_position.to_lat_long_alt(time)
    lat_long_alt.altitude.should be_close(57.2849647, 0.5e-7)
  end

  it "predicts deep space satellites" do
    tle = Predict::TLE.parse_three_line <<-TLE
      AO-40
      1 26609U 00072B   09105.66069202 -.00000356  00000-0  10000-3 0  2169
      2 26609 009.1977 023.4368 7962000 194.9139 106.0662 01.25584647 38840
      TLE
    time = Time.new(2009, 4, 17, 10, 10, 52)

    satellite = Predict::Satellite.new(tle)
    satellite_position, _ = satellite.predict(time)

    lat_long_alt = satellite_position.to_lat_long_alt(time)
    lat_long_alt.latitude.should be_close(0.0443606, 0.5e-7)
    lat_long_alt.longitude.should be_close(0.7094635, 0.5e-7)
    lat_long_alt.altitude.should be_close(58836.1341856, 0.5e-7)

    look_angle = GROUND_STATION.look_at(satellite_position, time)
    look_angle.azimuth.should be_close(2.2575500, 0.5e-7)
    look_angle.elevation.should be_close(0.4142781, 0.5e-7)
    look_angle.range.should be_close(62379.8441986, 0.5e-7)
  end

  it "predicts geosynchronous satellites" do
    tle = Predict::TLE.parse_three_line <<-TLE
      EUTELSAT 2-F1
      1 20777U 90079B   09356.31446792  .00000081  00000-0  10000-3 0  9721
      2 20777   9.6834  57.1012 0004598 207.1414 152.7950  0.99346230 50950
      TLE
    time = Time.new(2009, 12, 26, 0, 0, 0)

    satellite = Predict::Satellite.new(tle)
    satellite_position, _ = satellite.predict(time)

    lat_long_alt = satellite_position.to_lat_long_alt(time)
    lat_long_alt.latitude.should be_close(-0.1439317, 0.5e-7)
    lat_long_alt.longitude.should be_close(-2.7887656, 0.5e-7)
    lat_long_alt.altitude.should be_close(36031.8332336, 0.5e-7)

    look_angle = GROUND_STATION.look_at(satellite_position, time)
    look_angle.azimuth.should be_close(5.7534564, 0.5e-7)
    look_angle.elevation.should be_close(-0.8369032, 0.5e-7)
    look_angle.range.should be_close(46934.4073316, 0.5e-7)
  end

  it "predicts molniya orbits" do
    tle = Predict::TLE.parse_three_line <<-TLE
      MOLNIYA 1-80
      1 21118U 91012A   09357.87605320  .00001593  00000-0  10000-3 0  7339
      2 21118  61.8585 240.5458 7236516 255.2789  21.0579  2.00792202138149
      TLE
    time = Time.new(2009, 12, 26, 0, 0, 0)

    satellite = Predict::Satellite.new(tle)
    satellite_position, _ = satellite.predict(time)

    lat_long_alt = satellite_position.to_lat_long_alt(time)
    lat_long_alt.latitude.should be_close(0.8637110, 0.5e-7)
    lat_long_alt.longitude.should be_close(-3.0658979, 0.5e-7)
    lat_long_alt.altitude.should be_close(35278.911, 0.5e-3)

    look_angle = GROUND_STATION.look_at(satellite_position, time)
    look_angle.azimuth.should be_close(6.2095359, 0.5e-7)
    look_angle.elevation.should be_close(0.0574066, 0.5e-7)
    look_angle.range.should be_close(40812.259, 0.5e-3)
  end

  describe "#next_pass" do
    it "finds the next satellite pass" do
      tle = Predict::TLE.parse_three_line <<-TLE
        AO-51 [+]
        1 28375U 04025K   09105.66391970  .00000003  00000-0  13761-4 0  3643
        2 28375 098.0551 118.9086 0084159 315.8041 043.6444 14.40638450251959
        TLE
      time = Time.new(2009, 1, 5, 0, 0, 0)

      satellite = Predict::Satellite.new(tle)

      pass_start, pass_end = satellite.next_pass(at: GROUND_STATION, after: time)
      pass_start.should be_close(Time.new(2009, 1, 5, 4, 28, 10), 5.seconds)
      pass_end.should be_close(Time.new(2009, 1, 5, 4, 32, 15), 5.seconds)

      pass_start, pass_end = satellite.next_pass(at: GROUND_STATION, after: pass_end)
      pass_start.should be_close(Time.new(2009, 1, 5, 6, 4, 0), 5.seconds)
      pass_end.should be_close(Time.new(2009, 1, 5, 6, 18, 0), 5.seconds)

      pass_start, pass_end = satellite.next_pass(at: GROUND_STATION, after: pass_end)
      pass_start.should be_close(Time.new(2009, 1, 5, 7, 42, 45), 5.seconds)
      pass_end.should be_close(Time.new(2009, 1, 5, 7, 57, 50), 5.seconds)

      pass_start, pass_end = satellite.next_pass(at: GROUND_STATION, after: pass_end)
      pass_start.should be_close(Time.new(2009, 1, 5, 9, 22, 5), 5.seconds)
      pass_end.should be_close(Time.new(2009, 1, 5, 9, 34, 20), 5.seconds)

      pass_start, pass_end = satellite.next_pass(at: GROUND_STATION, after: pass_end)
      pass_start.should be_close(Time.new(2009, 1, 5, 11, 2, 5), 5.seconds)
      pass_end.should be_close(Time.new(2009, 1, 5, 11, 7, 35), 5.seconds)
    end

    it "finds the current pass with find_occuring_pass" do
      tle = Predict::TLE.parse_three_line <<-TLE
        AO-51 [+]
        1 28375U 04025K   09105.66391970  .00000003  00000-0  13761-4 0  3643
        2 28375 098.0551 118.9086 0084159 315.8041 043.6444 14.40638450251959
        TLE
      time = Time.new(2009, 1, 5, 4, 30, 0)

      satellite = Predict::Satellite.new(tle)

      pass_start, pass_end = satellite.next_pass(at: GROUND_STATION, after: time)
      pass_start.should be_close(Time.new(2009, 1, 5, 6, 4, 0), 5.seconds)
      pass_end.should be_close(Time.new(2009, 1, 5, 6, 18, 0), 5.seconds)

      pass_start, pass_end = satellite.next_pass(at: GROUND_STATION, after: time, find_occuring_pass: true)
      pass_start.should be_close(Time.new(2009, 1, 5, 4, 28, 10), 5.seconds)
      pass_end.should be_close(Time.new(2009, 1, 5, 4, 32, 15), 5.seconds)
    end
  end
end
