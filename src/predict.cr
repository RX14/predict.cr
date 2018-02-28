require "./predict/*"

module Predict
  VERSION = "0.1.2"

  REDUCED_JD_EPOCH  = Time.new(1858, 11, 16, 12, 0, 0, kind: Time::Kind::Utc)
  REDUCED_JD_OFFSET = 2400_000

  # Converts a crystal `Time` to a Julian date.
  def self.julian_date(time)
    reduced_julian = (time - REDUCED_JD_EPOCH).total_days
    reduced_julian + REDUCED_JD_OFFSET
  end
end
