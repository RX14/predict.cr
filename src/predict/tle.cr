module Predict
  # Represents an International Designator for a satellite. Also known as a
  # COSPAR designation or NSSDC ID.
  struct InternationalDesignator
    # The Gregorian calendar year that the satellite was launched.
    getter launch_year : Int32

    # Incrementing launch number of that year that the satellite was launched
    # on.
    getter launch_number : Int32

    # Sequential three letter code representing the piece of the launch.
    getter piece : String

    def initialize(@launch_year, @launch_number, @piece)
    end
  end

  # Represents the orbital elements contained in a two-line element set in a
  # normalised form.
  struct TLE
    # The human-readable name of the satellite.
    getter name : String

    # The NORAD catalogue number of this satellite.
    getter catalog_number : Int32

    # The `InternationalDesignator` of this satellite.
    getter international_designator : InternationalDesignator

    # The epoch time for this TLE in UTC.
    getter epoch : Time

    # Element set number of this TLE.
    getter element_set_number : Int32

    # The orbit number of the satellite at the epoch.
    getter revolution_number : Int32

    # Mean number of orbits per day the satellite completes.
    getter mean_motion : Float64

    # First derivative of mean motion with respect to time (in days).
    getter mean_motion_1st_deriv : Float64

    # Second derivative of mean motion with nrespect to time (in days).
    getter mean_motion_2nd_deriv : Float64

    # BSTAR coefficient, a term in the SGP4 predictor.
    getter radiation_pressure_coefficient : Float64

    # Inclination between the equator and orbit in degrees.
    getter inclination : Float64

    # The angle between the vernal equinox and the point where the orbit crosses
    # the equatorial plane going north in degrees.
    getter raan : Float64

    # A value defining the shape of the orbit.
    getter eccentricity : Float64

    # The angle between the ascending node and the orbit's perigee in degrees.
    getter argument_of_perigee : Float64

    # Mean anomaly in degrees.
    getter mean_anomaly : Float64

    def initialize(@name, @catalog_number, @international_designator, @epoch,
                   @element_set_number, @revolution_number, @mean_motion,
                   @mean_motion_1st_deriv, @mean_motion_2nd_deriv,
                   @radiation_pressure_coefficient, @inclination, @raan,
                   @eccentricity, @argument_of_perigee, @mean_anomaly)
    end

    # Parses a three line TLE (name, line1, line2). TLEs are sometimes supplied
    # with a leading zero on the name line, which this library will strip unless
    # *detect_zero_index* is set to false.
    def self.parse_three_line(string : String, *, detect_zero_index = true) : TLE
      # TODO: use each_line iterator after next release
      lines = string.chomp.split('\n')

      raise TLEParseException.new("Expected 3 lines but was #{lines.size}") unless lines.size == 3

      # Parse satellite name
      name_line = lines[0]
      if detect_zero_index && name_line[0] == '0'
        name = name_line[2..-1]
      else
        name = name_line
      end

      # Remove name line from lines
      lines.shift

      parse_two_line(lines, name)
    end

    # Reads a single three line TLE from IO. Returns nil if there's no TLE to
    # read. TLEs are sometimes supplied with a leading zero on the name line,
    # which this library will strip unless *detect_zero_index* is set to false.
    def self.parse_three_line(io : IO, *, detect_zero_index = true) : TLE?
      # TODO: use each_line iterator after next release

      # Parse satellite name
      name_line = io.gets.try(&.chomp)
      return unless name_line
      if detect_zero_index && name_line[0] == '0'
        name = name_line[2..-1]
      else
        name = name_line
      end

      line1 = io.gets.try(&.chomp)
      raise TLEParseException.new("Expected 3 lines but was 1") unless line1

      line2 = io.gets.try(&.chomp)
      raise TLEParseException.new("Expected 3 lines but was 2") unless line2

      parse_two_line({line1, line2}, name)
    end

    # Parses a two-line TLE given a tle string and a human-readable name.
    def self.parse_two_line(tle : String, name : String)
      parse_two_line(tle.chomp.split('\n'), name)
    end

    # Parses a two-line TLE given an array of two lines and a human-readable
    # name.
    def self.parse_two_line(lines : Indexable(String), name : String)
      raise TLEParseException.new("Expected 2 lines but was #{lines.size}") unless lines.size == 2

      line1 = lines[0]

      raise TLEParseException.new("No index on line 1") unless line1[0] == '1'

      catalog_number = line1[2..6].to_i

      designator_year = line1[9..10].to_i
      # Sputnik was launched in 1957, with the first international designator
      if designator_year >= 57
        designator_year += 1900
      else
        designator_year += 2000
      end

      designator_number = line1[11..13].to_i
      designator_piece = line1[14..16].strip

      designator = InternationalDesignator.new(designator_year, designator_number, designator_piece)

      epoch_year = line1[18..19].to_i
      if epoch_year >= 57
        epoch_year += 1900
      else
        epoch_year += 2000
      end

      # -1 because we want a day *offset* from the start of the year
      # instead of days *in* the year.
      epoch_days = line1[20..31].to_f - 1.0
      # TODO: remove before commit
      # epoch_days += year_to_days(epoch_year)
      # epoch = Time.new((epoch_days * Time::Span::TicksPerDay).to_i64, Time::Kind::Utc)
      epoch = Time.new(epoch_year, 1, 1) + epoch_days.days

      # Value in TLE is divided by two
      mean_motion_1st_deriv = line1[33..42].to_f * 2
      # Value in TLE is divided by 6
      mean_motion_2nd_deriv = 1.0e-5 * 6 * line1[44..49].to_i / 10.0**line1[51].to_i

      radiation_pressure_coefficient = 1.0e-5 * line1[53..58].to_i / 10.0**line1[60].to_i

      element_set_number = line1[64..67].to_i

      raise TLEParseException.new("Invalid Checksum: line 1") unless checksum(line1[0..67]) == line1[68].to_i

      line2 = lines[1]

      raise TLEParseException.new("No index on line 2") unless line2[0] == '2'
      raise TLEParseException.new("Catalogue numbers do not match") unless line2[2..6].to_i == catalog_number

      inclination = line2[8..15].to_f
      raan = line2[17..24].to_f
      eccentricity = 1.0e-7 * line2[26..32].to_i
      argument_of_perigee = line2[34..41].to_f
      mean_anomaly = line2[43..50].to_f
      mean_motion = line2[52..62].to_f
      revolution_number = line2[63..67].to_i

      raise TLEParseException.new("Invalid Checksum: line 2") unless checksum(line2[0..67]) == line2[68].to_i

      TLE.new(name, catalog_number, designator, epoch,
        element_set_number, revolution_number, mean_motion,
        mean_motion_1st_deriv, mean_motion_2nd_deriv,
        radiation_pressure_coefficient, inclination, raan, eccentricity,
        argument_of_perigee, mean_anomaly)
    end

    # Runs the checksum algorithm used by TLEs on the given string.
    def self.checksum(string)
      sum = 0
      string.each_char do |char|
        if '0' <= char <= '9'
          sum += char.to_i
        elsif char == '-'
          sum += 1
        end
      end

      sum % 10
    end

    private def self.year_to_days(year)
      (365*(year - 1)) + ((year - 1)/4) - ((year - 1)/100) + ((year - 1)/400)
    end
  end

  class TLEParseException < Exception
  end
end
