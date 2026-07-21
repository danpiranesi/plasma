module Plasma
  # Waveform peak generation.
  #
  # In the field this job belongs to BBC `audiowaveform`, run once on the Pi at
  # upload time so phones never decode audio just to draw a seekbar. Until real
  # recordings exist we synthesise an equivalent envelope from layered sinusoids.
  # The contract is what matters and is already correct: peaks are computed
  # server-side, are deterministic for a given seed, and are cacheable forever.
  module Waveform
    DEFAULT_RESOLUTION = 120

    # Envelope floor and ceiling. Peaks are normalised to 0.0..1.0 so the client
    # can scale to any canvas height without knowing the source amplitude.
    FLOOR = 0.04
    CEILING = 1.0

    module_function

    # Port of genWave() from the prototype. Kept numerically identical so the
    # Ruby-drawn peaks and the prototype's peaks are the same waveform --
    # test/parity_test.rb asserts this against fixtures captured from the JS.
    def generate(resolution = DEFAULT_RESOLUTION, seed = 1)
      # The JS used `seed || 1`, which also rewrites 0. Ruby's `||` would not.
      s = (seed.nil? || seed.zero?) ? 1 : seed

      Array.new(resolution) do |i|
        t = i.to_f / resolution
        v = 0.28 +
            0.22 * Math.sin(t * Math::PI * (6 + s % 5) + s * 0.7) +
            0.16 * Math.sin(t * Math::PI * (13 + s % 7) + s * 1.3) +
            0.10 * Math.sin(t * Math::PI * (27 + s % 3) + s * 2.1) +
            0.08 * Math.sin(t * Math::PI * 51 + s * 0.3) +
            0.06 * Math.sin(t * Math::PI * 4 + s * 1.7)
        v.clamp(FLOOR, CEILING)
      end
    end
  end
end
