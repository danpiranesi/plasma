module Plasma
  # A tag in the shared vocabulary.
  #
  # Categories carry an icon and a tone because the interface has to be
  # navigable without reading: the dial identifies a category by its icon and
  # speaks its tone on selection. The name is the secondary channel, not the
  # primary one.
  #
  # Hue deliberately carries no meaning. The archive once gave each category
  # its own colour; that failed on washed-out screens in daylight, so identity
  # moved entirely to icon, tone and position on the dial.
  class Category
    attr_reader :index, :name, :icon, :tone_hz, :archive_count, :recordings

    def initialize(index:, name:, icon:, tone_hz:, archive_count:, titles:)
      @index = index
      @name = name
      @icon = icon
      @tone_hz = tone_hz
      @archive_count = archive_count
      @recordings = titles.each_with_index.map do |title, i|
        Recording.new(category_index: index, index: i, title: title)
      end
    end

    def recording(index)
      recordings[index] if index && index >= 0 && index < recordings.length
    end

    def to_h
      {
        index: index,
        name: name,
        icon: icon,
        tone_hz: tone_hz,
        archive_count: archive_count,
        recordings: recordings.map(&:to_h)
      }
    end
  end
end
