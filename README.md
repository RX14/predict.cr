# predict.cr

Predict is a satellite prediction library for crystal using the sgp4 model.
The model used is the updated combined sgp/sdp4 model from the celestrak website.

Predict can track the latitude, longitude and altitude of satellites, and also calculate look angles (azimuth, elevation, range) from an observer on the earth's surface.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  predict:
    github: RX14/predict.cr
    version: 0.1.2
```

## Usage

```crystal
require "predict"

# All values truncated to 4 decimal places for readability

# Parse TLE
tle = Predict::TLE.parse_three_line <<-TLE
  ISS (ZARYA)
  1 25544U 98067A   16339.72355294  .00003337  00000-0  58323-4 0  9990
  2 25544  51.6456 287.6667 0006011 291.2532 140.8410 15.53794284 31519
  TLE
  
# Inspect TLE data
tle.name # => "ISS (ZARYA)"
tle.catalog_number # => 25544
tle.mean_motion # => 15.5379

# Create satellite from TLE, this initialises the orbital model
satellite = Predict::Satellite.new(tle)

# Create a prediction from the TLE
time = Time.new(2016, 12, 5, 12, 0, 0)
satellite_position, satellite_velocity = satellite.predict(time)

satellite_position # => Predict::TEME(@x=3815.7998, @y=1932.0874, @z=5261.6006)

# Predict ground track
satellite_position.to_lat_long_alt(time) # => Predict::LatLongAlt(@latitude=0.8913, @longitude=2.3062, @altitude=415.4529)

# Predict look angles from an observer (200m altitude)
observer = Predict::LatLongAlt.from_degrees(52.9, -2.24, 200.0)
observer.look_at(satellite_position, time) # => Predict::LookAngle(@azimuth=0.50118495648349193, @elevation=-0.55812612380797122, @range=7501.0178628601843)

# Predict next pass time
start_time, end_time = satellite.next_pass(at: observer, after: time)
start_time # => 2016-12-05 16:23:55
end_time # => 2016-12-05 16:32:29

# And the one after that...
start_time, end_time = satellite.next_pass(at: observer, after: end_time)
start_time # => 2016-12-05 17:58:46
end_time # => 2016-12-05 18:09:15
```

## Development

SGP4 is bound as a static library in src/predict/ext. Use `make` with the optional make variables `release=true` or `debug=true` to build the static library. Make sure you run the specs and formatter before sending PRs.

Useful reading material on sgp4 and coordinate systems is http://celestrak.com/columns/.

## Contributing

1. Fork it ( https://github.com/RX14/predict.cr/fork )
2. Create your feature branch (`git checkout -b feature/foo`)
3. Commit your changes (`git commit`)
4. Push to the branch (`git push origin feature/foo`)
5. Create a new Pull Request

## Contributors

- [RX14](https://github.com/RX14) - creator, maintainer, confused guy
