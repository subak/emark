require "active_support/core_ext/hash"
module SQLite3
  class Database
    def ordered_map_for columns, row
      h = HashWithIndifferentAccess[*columns.zip(row).flatten]
      row.each_with_index { |r, i| h[i] = r }
      h
    end
  end

  class Exception
    def code
      self.class.code || 500
    end
  end
end