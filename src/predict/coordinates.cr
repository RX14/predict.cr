private def sin(x)
  Math.sin(x)
end

private def cos(x)
  Math.cos(x)
end

private def tan(x)
  Math.tan(x)
end

private def arcsin(x)
  Math.asin(x)
end

private def arccos(x)
  Math.acos(x)
end

private def arctan(x)
  Math.atan(x)
end

private def arctan(dividend, divisor)
  Math.atan2(dividend, divisor)
end

private def sqrt(x)
  Math.sqrt(x)
end

private def gmst(time)
  Predict.greenwich_sidereal_time(time)
end

# Normalise an angle in radians to the range 0 <= angle < 2pi
private def normalize(angle)
  angle = angle % Predict::TWO_PI
  angle += Predict::TWO_PI if angle < 0.0
  angle
end

module Predict
  # Convert *time* to greenwich sidereal time in radians.
  def self.greenwich_sidereal_time(time : Time)
    greenwich_sidereal_time(julian_date(time))
  end

  # Convert *julian_date* to greenwich sidereal time in radians.
  def self.greenwich_sidereal_time(julian_date : Float64)
    julian_date_secs = (julian_date - julian_date.floor) * SECONDS_PER_DAY
    julian_century = (julian_date - J2000) / JULIAN_CENTURY_DAYS

    # Coefficients of IAU 1982 GMST-UT1 model
    a = 24110.54841 - (SECONDS_PER_DAY / 2) # offset by 0.5 days because julian dates start at noon
    b = 8640184.812866
    c = 0.093104
    d = -6.2e-6

    gmst = (a + (b + (c + d * julian_century) * julian_century) * julian_century) + julian_date_secs
    gmst *= TWO_PI / SECONDS_PER_DAY

    normalize(gmst)
  end

  # Coordinate vector in the TEME reference frame.
  # See http://celestrak.com/columns/v02n01/ for coordinate frame definition.
  struct TEME
    # X coordinate in km
    getter x : Float64

    # Y coordinate in km
    getter y : Float64

    # Z coordinate in km
    getter z : Float64

    def initialize(@x, @y, @z)
    end

    # Calculates the range vector from self to *other*.
    def range_to(other : TEME)
      TEME.new(other.x - @x, other.y - @y, other.z - @z)
    end

    # Converts these TEME coordinates to latitude, longitude and altitude at
    # *time*. See http://celestrak.com/columns/v02n03/ for algorithm used.
    def to_lat_long_alt(time, grav_type = GravityConstants::WGS72)
      const = GravityConstants[grav_type]

      xy = sqrt(@x * @x + @y * @y) # hypotenuse of triangle xy
      e_squared = const.flattening * (2.0 - const.flattening)

      longitude = normalize(arctan(@y, @x) - gmst(time))
      longitude -= TWO_PI if longitude > PI

      latitude = arctan(@z, xy)
      c = 0
      10.times do
        previous_latitude = latitude

        c = 1.0 / sqrt(1.0 - (e_squared * sin(latitude)**2))
        latitude = arctan(@z + const.radiusearthkm * c * e_squared * sin(latitude), xy)

        break if (previous_latitude - latitude).abs < 1e-12
      end

      altitude = (xy / cos(latitude)) - const.radiusearthkm * c

      LatLongAlt.new(latitude, longitude, altitude)
    end
  end

  # Struct containing latitude, longitude and altitude values.
  struct LatLongAlt
    # Latitude in radians, north positive
    getter latitude : Float64

    # Longitude in radians, east positive
    getter longitude : Float64

    # Altitude in kilometers
    getter altitude : Float64

    def initialize(@latitude, @longitude, @altitude)
    end

    # Creates a `LatLongAlt` from *lat* and *long* measured in degrees (where
    # North and East are positive) and *alt* in meters above sea level.
    def self.from_degrees(lat, long, alt)
      new(lat * DEG2RAD, long * DEG2RAD, alt / 1000)
    end

    # Converts latitude and longitude to TEME coordinates at `time`.
    def to_teme(time, grav_type = GravityConstants::WGS72) : TEME
      const = GravityConstants[grav_type]

      local_sidereal_time = normalize(gmst(time) + @longitude)

      # let f = flattening factor
      # let a = earth radius

      # let C = inverse sqrt(1 + f(f - 2)sin^2(latitude))
      c = 1.0 / sqrt(1 + const.flattening * (const.flattening - 2) * sin(@latitude)**2)
      # let S = (1 - f)^2 * C
      s = c * (1 - const.flattening)**2
      # (aC + altitude) * cos(latitude)
      ac_coslat = (c * const.radiusearthkm + @altitude) * cos(@latitude)

      x = ac_coslat * cos(local_sidereal_time)
      y = ac_coslat * sin(local_sidereal_time)
      z = (s * const.radiusearthkm + @altitude) * sin(@latitude)

      TEME.new(x, y, z)
    end

    # Calculates look angles to an object in TEME coordinate space.
    def look_at(other : TEME, time, grav_type = GravityConstants::WGS72) : LookAngle
      # See celestrak column 2
      const = GravityConstants[grav_type]
      local_sidereal_time = normalize(gmst(time) + @longitude)

      # Range vector in TEME coordinates
      range_vec = self.to_teme(time, const).range_to(other)

      sin_lat = sin(@latitude)
      cos_lat = cos(@latitude)
      sin_st = sin(local_sidereal_time)
      cos_st = cos(local_sidereal_time)

      topo_range_south = (sin_lat * cos_st * range_vec.x) +
                         (sin_lat * sin_st * range_vec.y) -
                         (cos_lat * range_vec.z)

      topo_range_east = (-sin_st * range_vec.x) +
                        (cos_st * range_vec.y)

      topo_range_up = (cos_lat * cos_st * range_vec.x) +
                      (cos_lat * sin_st * range_vec.y) +
                      (sin_lat * range_vec.z)

      range = sqrt(range_vec.x * range_vec.x +
                   range_vec.y * range_vec.y +
                   range_vec.z * range_vec.z)

      azimuth = arctan(-topo_range_east / topo_range_south)
      azimuth += PI if topo_range_south > 0
      azimuth += TWO_PI if azimuth < 0

      elevation = arcsin(topo_range_up / range)

      LookAngle.new(azimuth, elevation, range)
    end
  end

  # Struct containing a look angle consisting of azimuth, elevation and range.
  struct LookAngle
    # Azimuth (angle clockwise from north) in radians.
    getter azimuth : Float64

    # Elevation (angle above the horizon) in radians
    getter elevation : Float64

    # Range to the satellite in km.
    getter range : Float64

    def initialize(@azimuth, @elevation, @range)
    end
  end
end
