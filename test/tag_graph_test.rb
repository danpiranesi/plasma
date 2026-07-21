require_relative 'test_helper'

module Plasma
  class TagGraphTest < TestCase
    def graph
      archive.tag_graph
    end

    def test_neighbours_are_ranked_by_descending_weight
      weights = graph.neighbours(0).map { |n| n[:weight] }
      assert_equal weights.sort.reverse, weights
    end

    def test_edges_are_undirected
      # Edge [0, 1, 0.7] is stored once but must be visible from both ends.
      assert_includes graph.neighbours(0).map { |n| n[:category_index] }, 1
      assert_includes graph.neighbours(1).map { |n| n[:category_index] }, 0
      assert_in_delta graph.weight_between(0, 1), graph.weight_between(1, 0), 1e-12
    end

    def test_neighbours_respects_limit
      assert_equal 2, graph.neighbours(0, limit: 2).length
      assert_operator graph.neighbours(0, limit: 99).length, :<=, Archive::CATEGORY_COUNT
    end

    def test_neighbour_order_is_stable_across_calls
      # The petal layout is drawn from this order; if it shuffled between
      # requests the graph would appear to move on its own.
      assert_equal graph.neighbours(3), graph.neighbours(3)
    end

    def test_a_tag_is_never_its_own_neighbour
      Archive::CATEGORY_COUNT.times do |i|
        refute_includes graph.neighbours(i).map { |n| n[:category_index] }, i
      end
    end

    def test_unknown_tag_has_no_neighbours
      assert_empty graph.neighbours(99)
    end

    def test_weight_between_unconnected_tags_is_zero
      assert_in_delta 0.0, graph.weight_between(0, 3), 1e-12
    end

    def test_every_tag_is_reachable
      # An isolated tag would be a dead end in the Explore view.
      Archive::CATEGORY_COUNT.times do |i|
        refute_empty graph.neighbours(i), "tag #{i} has no connections"
      end
    end

    def test_rejects_edges_referencing_unknown_tags
      assert_raises(ArgumentError) { TagGraph.new([[0, 99, 0.5]], archive.categories) }
    end

    def test_rejects_self_loops
      assert_raises(ArgumentError) { TagGraph.new([[2, 2, 0.5]], archive.categories) }
    end

    def test_rejects_out_of_range_weights
      assert_raises(ArgumentError) { TagGraph.new([[0, 1, 0.0]], archive.categories) }
      assert_raises(ArgumentError) { TagGraph.new([[0, 1, 1.5]], archive.categories) }
    end
  end
end
