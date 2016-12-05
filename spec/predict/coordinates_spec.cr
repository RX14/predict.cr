require "../spec_helper"

private def gmst(time)
  Predict.greenwich_sidereal_time(time)
end

describe Predict do
  describe ".greenwich_sidereal_time" do
    it "calculates the correct GMST" do
      gmst(Time.new(1995, 10, 1, 9, 0, 0)).should eq(2.5242182677688412)
      # From IAU sofa tests
      gmst(2400000.5 + 53736.0).should be_close(1.754174981860675096, 1e-12)
    end
  end

  describe "TEME" do
    describe "#to_lat_long_alt" do
      it "converts TEME to lat/long/alt" do
        teme = Predict::TEME.new(-4400.594, 1932.870, 4760.712)
        expected = teme.to_lat_long_alt(Time.new(1995, 11, 18, 12, 46, 0))

        expected.latitude.should be_close(44.91 * Predict::DEG2RAD, 0.5e-2)
        expected.longitude.should be_close(-92.31 * Predict::DEG2RAD, 0.5e-2)
        expected.altitude.should be_close(397.507, 0.5e-3)
      end

      it "round trips" do
        time = Time.new(1995, 11, 18, 12, 46, 0)
        expected = Predict::TEME.new(-4400.594, 1932.870, 4760.712)
        actual = expected.to_lat_long_alt(time).to_teme(time)

        actual.x.should be_close(expected.x, 1e-10)
        actual.y.should be_close(expected.y, 1e-10)
        actual.z.should be_close(expected.z, 1e-10)
      end

      it "round trips (random)" do
        time = random_time
        expected = random_teme
        actual = expected.to_lat_long_alt(time).to_teme(time)

        actual.x.should be_close(expected.x, 1e-10)
        actual.y.should be_close(expected.y, 1e-10)
        actual.z.should be_close(expected.z, 1e-10)
      end
    end
  end

  describe "LatLongAlt" do
    describe "#to_teme" do
      it "converts latitude/longitude/altitude to TEME" do
        pos = Predict::LatLongAlt.from_degrees(40.0, -75.0, 0.0)
        teme = pos.to_teme(Time.new(1995, 10, 1, 9, 0, 0))

        teme.x.should be_close(1703.295, 0.5e-3)
        teme.y.should be_close(4586.650, 0.5e-3)
        teme.z.should be_close(4077.984, 0.5e-3)
      end

      it "round trips" do
        time = Time.new(1995, 10, 1, 9, 0, 0)
        expected = Predict::LatLongAlt.from_degrees(40.0, -75.0, 0.0)
        actual = expected.to_teme(time).to_lat_long_alt(time)

        actual.latitude.should be_close(expected.latitude, 1e-10)
        actual.longitude.should be_close(expected.longitude, 1e-10)
        actual.altitude.should be_close(expected.altitude, 1e-10)
      end

      it "round trips (random)" do
        time = random_time
        expected = random_lla
        actual = expected.to_teme(time).to_lat_long_alt(time)

        actual.latitude.should be_close(expected.latitude, 1e-10)
        actual.longitude.should be_close(expected.longitude, 1e-10)
        actual.altitude.should be_close(expected.altitude, 1e-10)
      end
    end

    describe "#look_at" do
      # it "finds look angles to a satellite" do
      #   time = Time.new(1995, 11, 18, 12, 46, 0)
      #   satellite = Predict::TEME.new(-4400.594, 1932.870, 4760.712)
      #   observer = Predict::LatLongAlt.new(45.0, -93.0, 0.0)

      #   look_angle = observer.look_at(satellite, time)

      #   look_angle.azimuth.should be_close(100.36 * Predict::DEG2RAD, 0.5e-2)
      #   look_angle.elevation.should be_close(81.52 * Predict::DEG2RAD, 0.5e-2)
      #   look_angle.range.should be_close(81.52 * Predict::DEG2RAD, 0.5e-2)
      # end
    end
  end
end
