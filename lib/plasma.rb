# PLASMA -- Participatory Listening and Sense-Making of Archives
#
# Built with Janastu/Servelots (https://janastu.org) for the community archive
# at Devarayanadurga, Karnataka.
#
# Load order matters: Recording and Category are referenced while Archive parses
# the catalogue at boot.
module Plasma
  VERSION = '0.1.0'.freeze
end

require_relative 'plasma/waveform'
require_relative 'plasma/recording'
require_relative 'plasma/category'
require_relative 'plasma/tag_graph'
require_relative 'plasma/archive'
require_relative 'plasma/annotation'
require_relative 'plasma/annotation_store'
