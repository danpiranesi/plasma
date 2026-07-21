module Plasma
  # Weighted co-occurrence between tags, drawn as the petals of the Explore view.
  #
  # An undirected graph: [a, b, weight] means tags a and b are found together
  # in the archive with that strength. Edges are stored once, in either
  # direction, and this class handles the symmetry.
  class TagGraph
    attr_reader :edges

    def initialize(edges, categories)
      @edges = edges.map { |a, b, w| [a, b, w.to_f] }.freeze
      @categories = categories
      validate!
    end

    # Tags adjacent to the given one, strongest first. Weights accumulate, so a
    # pair joined by more than one edge ranks higher than either edge alone.
    def neighbours(category_index, limit: nil)
      scores = Hash.new(0.0)

      edges.each do |a, b, weight|
        scores[b] += weight if a == category_index
        scores[a] += weight if b == category_index
      end

      ranked = scores
               .map { |index, weight| { category_index: index, weight: weight } }
               # Tie-break on index so the petal layout is stable between
               # requests; Ruby's sort is not stable on its own.
               .sort_by { |n| [-n[:weight], n[:category_index]] }

      limit ? ranked.first(limit) : ranked
    end

    def weight_between(a, b)
      edges.sum { |x, y, w| (x == a && y == b) || (x == b && y == a) ? w : 0.0 }
    end

    private

    def validate!
      edges.each do |a, b, weight|
        raise ArgumentError, "tag_graph edge references unknown tag: #{[a, b].inspect}" unless
          valid_index?(a) && valid_index?(b)
        raise ArgumentError, "tag_graph edge is a self-loop: #{a}" if a == b
        raise ArgumentError, "tag_graph weight out of range: #{weight}" unless weight.positive? && weight <= 1.0
      end
    end

    def valid_index?(index)
      index.is_a?(Integer) && index >= 0 && index < @categories.length
    end
  end
end
