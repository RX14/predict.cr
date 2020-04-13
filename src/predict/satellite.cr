private def converge_root(a, b, *, accuracy = 1e-6, max_iterations = 40)
  xa = yield a
  xb = yield b

  raise "Root is not bracketed" unless (xa * xb) <= 0

  if xa < 0
    # Function is increasing a -> b
    dx = b - a
    root = a
  else
    # Function is decreasing a -> b
    dx = a - b
    root = b
  end

  # In this algorithm, the search section is described by the lower bound of
  # *root*, and the upper bound of *root + dx*. Halving dx is equivalent to
  # taking the left section, halving dx and setting root to be the midsection is
  # equivalent to taking the right section.

  max_iterations.times do |i|
    dx *= 0.5                        # halve dx
    xmid = root + dx                 # calculate x value of midsection
    fmid = yield xmid                # find function value at midsection
    root = xmid if fmid <= 0         # midsection is below root, take right section
    return root if dx.abs < accuracy # the root is always within (root + dx), so if dx < accuracy we can return
  end

  raise "Root finding failed: too many iterations"
end

module Predict
  # Struct containing an initialised SGP4 model of a satellite.
  class Satellite
    getter tle : TLE
    getter satrec = SGP4::Elset.new
    getter constants : GravityConstants
    @epoch : Time

    # Initialises the `Satellite` with *tle*, using *grav_type*
    def initialize(@tle : TLE, grav_type = GravityConstants::WGS72)
      @constants = GravityConstants[grav_type]
      @epoch = tle.epoch
      initialize_satrec(tle)
    end

    private def initialize_satrec(tle)
      @satrec.satnum = tle.catalog_number
      @satrec.epochyr = tle.epoch.year % 100
      @satrec.epochdays = (tle.epoch - tle.epoch.at_beginning_of_year).total_days + 1.0
      @satrec.ndot = tle.mean_motion_1st_deriv / 2
      @satrec.nddot = tle.mean_motion_2nd_deriv / 6
      @satrec.bstar = tle.radiation_pressure_coefficient
      @satrec.inclo = tle.inclination
      @satrec.nodeo = tle.raan
      @satrec.ecco = tle.eccentricity
      @satrec.argpo = tle.argument_of_perigee
      @satrec.mo = tle.mean_anomaly
      @satrec.no = tle.mean_motion

      # Convert units
      @satrec.no /= XPDOTP
      @satrec.ndot /= XPDOTP * MINS_PER_DAY
      @satrec.nddot /= XPDOTP * (MINS_PER_DAY**2)

      @satrec.inclo *= DEG2RAD
      @satrec.nodeo *= DEG2RAD
      @satrec.argpo *= DEG2RAD
      @satrec.mo *= DEG2RAD

      @satrec.a = (@satrec.no*@constants.tumin)**(-TWO_THIRDS)
      @satrec.alta = @satrec.a * (1.0 + @satrec.ecco) - 1.0
      @satrec.altp = @satrec.a * (1.0 - @satrec.ecco) - 1.0

      @satrec.jdsatepoch = Predict.julian_date(tle.epoch)

      SGP4.init(@constants.type, 'i'.ord.to_u8, @satrec.satnum, @satrec.jdsatepoch - 2433281.5, @satrec.bstar,
        @satrec.ecco, @satrec.argpo, @satrec.inclo, @satrec.mo, @satrec.no, @satrec.nodeo, pointerof(@satrec))

      check_error
    end

    # Returns true equator mean equinox (TEME) vectors for position and velocity
    # from SGP4. Vectors are returned in the order position, velocity. Units are
    # km and km/s.
    def predict(time)
      tsince = (time - @epoch).total_minutes

      r = uninitialized LibC::Double[3]
      v = uninitialized LibC::Double[3]
      SGP4.run(@constants.type, pointerof(@satrec), tsince, r, v)
      check_error

      position = TEME.new(r[0], r[1], r[2])
      velocity = TEME.new(v[0], v[1], v[2])
      {position, velocity}
    end

    private def look_angles(location, time)
      satellite_position, _ = predict(time)
      location.look_at(satellite_position, time)
    end

    # Finds the next pass at *location* occuring after the given time. When
    # *find_occuring_pass* is true, a satellite pass currently in progress at
    # the supplied time may be returned. The returned value is a tuple of pass
    # start time followed by pass end time.
    def next_pass(*, at : LatLongAlt, after : Time, find_occuring_pass = false) : {Time, Time}
      time = after
      location = at

      raise "Satellite will never be visible" unless pass_possible? location

      orbit_time = (MINS_PER_DAY / tle.mean_motion).minutes

      # Wind back 1/4 orbit if we want to find currently occurring passes
      time -= orbit_time / 4 if find_occuring_pass

      look_angles = look_angles(location, time)

      # Ensure satellite is not above the horizon
      if look_angles.elevation > 0
        # Move forward in 60 second intervals until the satellite goes below the horizon
        while look_angles.elevation > 0
          time += 60.seconds
          look_angles = look_angles(location, time)
        end

        # Move forward 3/4 orbit
        time += orbit_time * 0.75
        look_angles = look_angles(location, time)
      end

      # Find the time it comes over the horizon
      while look_angles.elevation < 0
        time += 60.seconds
        look_angles = look_angles(location, time)
      end

      # Find pass start
      start_time = converge_root(time, time - 60.seconds, accuracy: 1.millisecond) do |time|
        look_angles(location, time).elevation
      end

      # Find the time when it goes below
      while look_angles.elevation > 0
        time += 30.seconds
        look_angles = look_angles(location, time)
      end

      # p look_angles.elevation
      # p look_angles(location, time - 30.seconds).elevation

      # Find los time
      end_time = converge_root(time, time - 30.seconds, accuracy: 1.millisecond) do |time|
        look_angles(location, time).elevation
      end

      {start_time, end_time}
    end

    # Returns true if it's possible for the satellite to be visible from
    # *location*.
    def pass_possible?(location : LatLongAlt)
      return false if tle.mean_motion < 1e-8

      incl = tle.inclination
      incl = 180 - incl if incl >= 90.0
      incl *= DEG2RAD

      # Cube root of Kepler's third law constant for the earth and satellite
      # with negligible mass, expressed in (km^3/s^2).
      k = 331.25

      semi_major_axis = k * (MINS_PER_DAY / tle.mean_motion)**TWO_THIRDS
      apogee = semi_major_axis * (1.0 + tle.eccentricity) # From center of earth
      ground_track_angle = Math.acos(@constants.radiusearthkm / apogee)

      ground_track_angle + incl > location.latitude.abs
    end

    private def check_error
      case @satrec.error
      when 0
        # OK
      when 1
        raise "Eccentricity >= 1.0 or < -0.001"
      when 2
        raise "Mean motion < 0"
      when 3
        raise "Pert elements: eccentricity < 0 or > 1"
      when 4
        raise "Semi-latus rectum < 0"
      when 5
        raise "Epoch elements were sub-orbital"
      when 6
        raise "Satellite has decayed"
      else
        raise "Unknown Error #{@satrec.error}"
      end
    end
  end
end
