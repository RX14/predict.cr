module Predict
  # Mathematical constants
  PI         = Math::PI
  TWO_PI     = PI * 2
  DEG2RAD    = PI / 180.0
  TWO_THIRDS = 2.0/3.0

  # Time constants
  MINS_PER_DAY    =  1440.0
  SECONDS_PER_DAY = 86400.0
  # Julian date of the J2000 epoch (January 1 2000 12:00 GMT)
  J2000 = 2_451_545.0
  # Length of a Julian century in days
  JULIAN_CENTURY_DAYS = 36_525.0

  # WTF constants
  XPDOTP = MINS_PER_DAY / TWO_PI

  # Gravity constants used by the SGP4 algorithm. Using variants of this class
  # lets you change between WGS72 and WGS84 easily.
  struct GravityConstants
    WGS72Old = new(SGP4::GravConstType::WGS72Old)
    WGS72    = new(SGP4::GravConstType::WGS72)
    WGS84    = new(SGP4::GravConstType::WGS84)

    def self.[](grav_type) : GravityConstants
      return grav_type if grav_type.is_a? GravityConstants

      case grav_type
      when SGP4::GravConstType::WGS72Old
        WGS72Old
      when SGP4::GravConstType::WGS72
        WGS72
      when SGP4::GravConstType::WGS84
        WGS84
      else
        raise "Invalid gravity type"
      end
    end

    getter type : SGP4::GravConstType
    getter radiusearthkm : Float64
    getter flattening : Float64
    getter tumin : Float64
    getter mu : Float64
    getter xke : Float64
    getter j2 : Float64
    getter j3 : Float64
    getter j4 : Float64
    getter j3oj2 : Float64

    private def initialize(@type : SGP4::GravConstType)
      case type
      when SGP4::GravConstType::WGS72Old
        @radiusearthkm = 6378.135 # km
        @flattening = 1 / 298.26
        @mu = 398600.79964 # in km3 / s2
        @xke = 0.0743669161
        @tumin = 1.0 / @xke
        @j2 = 0.001082616
        @j3 = -0.00000253881
        @j4 = -0.00000165597
        @j3oj2 = @j3 / @j2
      when SGP4::GravConstType::WGS72
        @radiusearthkm = 6378.135 # km
        @flattening = 1 / 298.26
        @mu = 398600.8 # in km3 / s2
        @xke = 60.0 / Math.sqrt(radiusearthkm**3 / @mu)
        @tumin = 1.0 / @xke
        @j2 = 0.001082616
        @j3 = -0.00000253881
        @j4 = -0.00000165597
        @j3oj2 = @j3 / @j2
      when SGP4::GravConstType::WGS84
        @radiusearthkm = 6378.137 # km
        @flattening = 1 / 298.257223563
        @mu = 398600.5 # in km3 / s2
        @xke = 60.0 / Math.sqrt(radiusearthkm**3 / @mu)
        @tumin = 1.0 / @xke
        @j2 = 0.00108262998905
        @j3 = -0.00000253215306
        @j4 = -0.00000161098761
        @j3oj2 = @j3 / @j2
      else
        raise "Invalid gravity type"
      end
    end
  end
end
