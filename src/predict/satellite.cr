module Predict
  # Struct containing an initialised SGP4 model of a satellite.
  struct Satellite
    getter satrec = SGP4::Elset.new
    getter constants : GravityConstants
    @epoch : Time

    # Initialises the `Satellite` with *tle*, using *grav_type*
    def initialize(tle : TLE, grav_type = GravityConstants::WGS72)
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

    private def check_error
      case @satrec.error
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
      end
    end
  end
end
