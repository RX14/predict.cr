require "spec"
require "../src/predict"

@[Link(ldflags: "#{__DIR__}/../src/predict/ext/sgp4.a")]
lib SGP4
  fun twoline2rv(line1 : LibC::Char[130], line2 : LibC::Char[130],
                 typerun : LibC::Char, typeinput : LibC::Char, opsmode : LibC::Char,
                 whichconst : Predict::SGP4::GravConstType,
                 startmfe : LibC::Double*, stopmfe : LibC::Double*, deltamin : LibC::Double*,
                 satrec : Predict::SGP4::Elset*)
end

RANDOM_TIME_START_TICKS = Time.new(1990, 1, 1).ticks
RANDOM_TIME_END_TICKS   = Time.new(2020, 1, 1).ticks

def random_time
  Time.new(rand(RANDOM_TIME_START_TICKS..RANDOM_TIME_END_TICKS))
end

def random_teme
  Predict::TEME.new(rand(-10_000.0..10_000.0), rand(-10_000.0..10_000.0), rand(-10_000.0..10_000.0))
end

def random_lla
  Predict::LatLongAlt.from_degrees(rand(-90..90), rand(-180..180), rand(-500.0..2000.0))
end
