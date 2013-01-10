require 'active_record'

module ActiveSql
  autoload :Finder, 'active_sql/finder'
  autoload :Condition, 'active_sql/condition'
  autoload :SortCondition, 'active_sql/sort_condition'
end

ActiveRecord::Base.extend(ActiveSql::Finder)
