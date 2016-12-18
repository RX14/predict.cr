require "../spec_helper"

private def check(tle : Predict::TLE)
  tle.name.should eq("AO-51 [+]")
  tle.catalog_number.should eq(28375)
  tle.international_designator.launch_year.should eq(2004)
  tle.international_designator.launch_number.should eq(25)
  tle.international_designator.piece.should eq("K")
  tle.epoch.should be_close(Time.new(2009, 4, 15, 15, 56, 2, 662.079, Time::Kind::Utc), 1.millisecond)
  tle.element_set_number.should eq(364)
  tle.revolution_number.should eq(25195)
  tle.mean_motion.should be_close(14.4063845, 1e-7)
  tle.mean_motion_1st_deriv.should eq(6e-8)
  tle.mean_motion_2nd_deriv.should eq(0)
  tle.radiation_pressure_coefficient.should be_close(1.3761e-5, 1e-9)
  tle.inclination.should eq(98.0551)
  tle.raan.should eq(118.9086)
  tle.eccentricity.should eq(0.0084159)
  tle.argument_of_perigee.should eq(315.8041)
  tle.mean_anomaly.should eq(43.6444)
end

private def tle
  <<-TLE
  1 28375U 04025K   09105.66391970  .00000003  00000-0  13761-4 0  3643
  2 28375 098.0551 118.9086 0084159 315.8041 043.6444 14.40638450251959
  TLE
end

private def tle_name
  <<-TLE
  AO-51 [+]
  1 28375U 04025K   09105.66391970  .00000003  00000-0  13761-4 0  3643
  2 28375 098.0551 118.9086 0084159 315.8041 043.6444 14.40638450251959
  TLE
end

private def tle_name_zero
  <<-TLE
  0 AO-51 [+]
  1 28375U 04025K   09105.66391970  .00000003  00000-0  13761-4 0  3643
  2 28375 098.0551 118.9086 0084159 315.8041 043.6444 14.40638450251959
  TLE
end

describe Predict::TLE do
  it "parses a TLE" do
    parsed = Predict::TLE.parse_two_line(tle, "AO-51 [+]")
    check(parsed)
  end

  it "parses a 3LE" do
    parsed = Predict::TLE.parse_three_line(tle_name)
    check(parsed)
  end

  it "parses a 3LE with name" do
    parsed = Predict::TLE.parse_three_line(tle_name_zero)
    check(parsed)
  end

  it "reads a 3LE from IO" do
    io = IO::Memory.new <<-TLE
      0 AO-51 [+]
      1 28375U 04025K   09105.66391970  .00000003  00000-0  13761-4 0  3643
      2 28375 098.0551 118.9086 0084159 315.8041 043.6444 14.40638450251959
      ISS (ZARYA)
      1 25544U 98067A   16353.55251028  .00001623  00000-0  32018-4 0  9996
      2 25544  51.6442 218.7617 0006358 347.8298  93.3295 15.53909678 33661
      TLE

    tles = Array(Predict::TLE).new
    2.times { tles << Predict::TLE.parse_three_line(io).not_nil! }

    check(tles[0])
    tles[1].name.should eq("ISS (ZARYA)")

    Predict::TLE.parse_three_line(io).should be_nil
  end
end
