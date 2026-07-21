require 'yaml'

module Plasma
  # The archive catalogue: every category and every recording.
  #
  # Loaded once at boot from data/archive.yml and then frozen. The catalogue is
  # small and read-only, so the Pi holds it in memory rather than hitting SQLite
  # on every request -- and the shell inlines it, so browsing costs no network.
  class Archive
    CATEGORY_COUNT = 12

    DEFAULT_PATH = File.expand_path('../../data/archive.yml', __dir__)

    attr_reader :categories, :tag_graph, :annotation_labels

    def self.load(path = DEFAULT_PATH)
      new(YAML.safe_load_file(path))
    end

    # The process-wide catalogue. Reloadable in tests via .load.
    def self.default
      @default ||= load
    end

    def initialize(data)
      @categories = data.fetch('categories').each_with_index.map do |c, i|
        Category.new(
          index: i,
          name: c.fetch('name'),
          icon: c.fetch('icon'),
          tone_hz: c.fetch('tone_hz').to_f,
          archive_count: c.fetch('archive_count'),
          titles: c.fetch('recordings')
        )
      end
      @tag_graph = TagGraph.new(data.fetch('tag_graph'), @categories)
      @annotation_labels = data.fetch('annotation_labels').freeze
    end

    def category(index)
      categories[index] if index && index >= 0 && index < categories.length
    end

    def recordings
      @recordings ||= categories.flat_map(&:recordings)
    end

    # Look up by the "<category>-<recording>" id the dial navigates by.
    # Returns nil for anything malformed rather than raising, because this is
    # fed directly by request parameters.
    def recording(id)
      return nil unless id.is_a?(String)

      match = /\A(\d+)-(\d+)\z/.match(id)
      return nil unless match

      category(match[1].to_i)&.recording(match[2].to_i)
    end

    def valid_tag_index?(index)
      index.is_a?(Integer) && index >= 0 && index < categories.length
    end

    # Every recording carrying all of the given tags. This is the query behind
    # the Explore view: pick two tags, see where the archive already connects
    # them. Fewer than two tags is not an intersection, so it returns nothing.
    def recordings_tagged_with(tag_indices)
      return [] if tag_indices.length < 2
      return [] unless tag_indices.all? { |t| valid_tag_index?(t) }

      recordings.select { |r| (tag_indices - r.tag_indices).empty? }
    end

    def to_h
      {
        categories: categories.map(&:to_h),
        tag_graph: tag_graph.edges,
        annotation_labels: annotation_labels
      }
    end
  end
end
