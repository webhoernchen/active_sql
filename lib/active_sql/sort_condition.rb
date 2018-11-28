# ActiveSql::SortCondition is a libary to write 
# complicated sql conditions for sorting in a Rails like
# 
# You can set the conditions and 
# use the method "to_sort_condition" to use the condition
# in the sort option of the ActiveRecord.find.
# 
# 
# 
# Examples:
# +Call the methods self+:
#   condition = ActiveSql::Condition.new(:klass => Product)
#   condition.manufacturer.name.to_sort_condition
#   => "(SELECT GROUP_CONCAT(102_manufacturers.name ORDER BY 102_manufacturers.name SEPARATOR ' ') FROM manufacturers 102_manufacturers WHERE 102_manufacturers.id IN (products.manufacturer_id))"
# 
# +To Easer use this functionality use the sort_by_active_sql method of the RecordClass+:
#   Product.sort_by_active_sql do |product|
#     product.manufacturer.name
#   end
#   => "(SELECT GROUP_CONCAT(102_manufacturers.name ORDER BY 102_manufacturers.name SEPARATOR ' ') FROM manufacturers 102_manufacturers WHERE 102_manufacturers.id IN (products.manufacturer_id))"
#

module ActiveSql
  class SortError < StandardError; end

  class SortCondition
    
    DEFAULT_LIMIT = 1

    VALID_SORTS = ['ASC', 'DESC', 'IS NULL']
    
    # All Attributes are protected
    # because it is not needed to change this attributes outside this class
    protected
    attr_accessor :klass, :column_name, :reflection, :parent, :condition_index,
      :child, :limit, :count, :sum

    attr_writer :quoted_table_name
    attr_reader :sort, :inner_sort, :custom_sort, :condition_sql
    
    public
    ## Only 1 Argument is needed to initialize this Condition
    # All other Arguments are used intern
    # 
    # options can be:
    # +klass+: (+required+) the RecordClass to create the condition
    def initialize(options)
      self.klass = options[:klass] || options[:reflection].klass
      self.column_name = options[:column_name]
      self.reflection = options[:reflection]
      self.parent = options[:parent]
      self.condition_index = options[:condition_index] || 2000
      self.quoted_table_name = options[:quoted_table_name]
      self.sort = options[:sort]
      self.inner_sort = options[:inner_sort]
      self.custom_sort = options[:custom_sort]
      self.count = options[:count] || false
      self.sum = options[:sum] || false
      self.limit = options[:limit] || DEFAULT_LIMIT
    end

    def start_index
      @start_index ||= parent ? parent.start_index : condition_index
    end

    def condition(&block)
      if block_given?
        active_sql_condition = ActiveSql::Condition.new(:klass => klass, 
          :condition_index => condition_index, :table_name => quoted_table_name)
        yield(active_sql_condition)
        self.condition_sql = klass.send(:sanitize_sql, active_sql_condition.to_record_conditions)
      end
      self
    end
    
    # returns the sort condition as sql string
    # can be user directly with the sort option from ActiveRecord::Base
    def to_sort_condition(with_order=true)
      @with_order = with_order
      if reflection
        send("sql_by_#{reflection.macro}_reflection")
      else
        sql_column_name_condition
      end
    end

    def full_name
      if parent
        if reflection
          [parent.full_name, reflection.name].join('__')
        else
          [parent.full_name, column_name].join('__')
        end
      else
        table_name
      end
    end
    
    # the default method missing is overwritten here to accepts the columns 
    # for the condition in a easily understanding api
    #
    # the name is a reflection of the given klass,
    # => then a new child_condition will be crated and returned for the reflection
    #
    # the name is a column of the given klass,
    # => then a new child_condition will be crated and returned for the column name
    #
    # returns nil if 
    # * no child were found, 
    # * no reflection were found or
    # * no column name were found
    def method_missing(name, *args, &block)
      options = args.detect {|v| v.is_a?(Hash)} || {}
      args.delete(options)
      
      if reflection_from_klass = klass.reflect_on_association(name)
        self.child = create_child_by_reflection(reflection_from_klass, options)
      elsif klass.column_names.include?(name.to_s)
        self.child = create_child_by_column(name.to_s, options)
#      elsif klass.respond_to? name
#        by_scope unscoped_klass.send(name, *args)
      else
        super
      end
    end

    def by_column(name, options={})
      self.child = create_child_by_column(name.to_s, options)
    end

    def pk
      by_column klass.primary_key
    end
    alias by_pk pk

#    def by_scope(scope)
#      raise ScopeError, 'no scope given' unless scope && scope.respond_to?(:where_or_scoped)
#
#      sql = if scope.respond_to? :arel
#        scope.arel.orders.collect do |item|
#          item.respond_to?(:to_sql) ? item.to_sql : item.to_s
#        end.join(', ')
#      else
#        scope.to_sql.split('ORDER BY')[1..-1].join('ORDER BY').strip
#      end
#
#      by_column sql
#    end
    
    protected
    def unscoped_klass
      @unscoped_klass ||= if klass.respond_to? :unscoped
        klass.unscoped
      else
        klass
      end
    end

    def parent_klass
      parent.klass
    end

    # returns the table name from the klass
    def table_name
      klass.table_name
    end  
    
    def quoted_table_name
      @quoted_table_name ||= quote_table_name table_name
    end
    
    def quoted_child_table_name
      @quoted_child_table_name ||= child.quoted_table_name
    end
    
    def primary_key_name
      reflection.respond_to?(:foreign_key) ? reflection.foreign_key : reflection.primary_key_name
    end
    
    def join_table
      reflection.through_reflection ? reflection.through_reflection.table_name : reflection.options[:join_table]
    end
    
    def quoted_join_table
      @quoted_join_table ||= quote_table_name join_table
    end
    
    def association_foreign_key
      reflection.association_foreign_key
    end

    def condition_sql=(value)
      @condition_sql = value
    end
    
    private
    def sort=(value)
      if VALID_SORTS.include?(value) || value.nil?
        @sort = value
      else
        raise ActiveSql::SortError, "SORT can only be one of the following list '#{VALID_SORTS.join("', '")}'. But was #{value}"
      end
    end
    
    def inner_sort=(value)
      if VALID_SORTS.include?(value) || value.nil?
        @inner_sort = value
      else
        raise ActiveSql::SortError, "INNER_SORT can only be one of the following list '#{VALID_SORTS.join("', '")}'. But was #{value}"
      end
    end
    
    def custom_sort=(ordered_hash=nil)
      unless ordered_hash.blank?
        valid_order = (ordered_hash.values.collect(&:to_s) - VALID_SORTS).empty?
        valid_columns = ordered_hash.keys.all? do |col| 
          klass.column_names.include?(col.to_s) || col.to_s.include?(parent.table_name)
        end

        if valid_order && valid_columns
          @custom_sort = ordered_hash.collect do |k, v|
            if k.to_s.include?(parent.table_name)
              column = k.gsub(parent.table_name, parent.quoted_table_name)
              "#{column} #{v}"
            else
              "#{parent.quoted_table_name}.#{k} #{v}"
            end
          end.join(', ')
        else
          raise ActiveSql::SortError, "CUSTOM_SORT can only be a Hash with valid column and sorting"
        end
      end
    end

    # creates a new child condition for a reflection
    # +reflection+: Instance of a reflection of the reflection hash from the given klass
    def create_child_by_reflection(reflection, options={})
      klass = options[:is] ? options[:is].to_s.classify.constantize : nil
      klass = options[:klass] if klass.nil? && options[:klass]
      
      raise ActiveSql::PolymorphicError,
        "Need option :is => class_name for a polymorphic belongs_to reflection" \
        if reflection.options[:foreign_type] && klass.nil? && ONE_REFLECTION_MACROS.include?(reflection.macro)
      
      self.class.new({:reflection => reflection, 
                      :parent => self,
                      :sort => sort, :count => count, :sum => sum,
                      :condition_index => condition_index.next,
                      :klass => klass})
    end
    
    # creates a new child condition for a column name
    # +name+: column name of the given klass
    def create_child_by_column(name, options={})
      options.symbolize_keys!.assert_valid_keys(:count, :sum, :sort, :limit, :inner_sort, :custom_sort)

      self.class.new({:klass => klass, 
                      :parent => self,
                      :column_name => name,
                      :condition_index => condition_index.next,
                      :sort => options[:sort] || sort,
                      :inner_sort => options[:inner_sort] || sort,
                      :custom_sort => options[:custom_sort],
                      :count => options[:count] || count,
                      :sum => options[:sum] || sum,
                      :limit => options[:limit]})
    end
    
    # returns the condition option of the reflection 
    # and sanitize the condition to an sql string
    #
    # to identify the correct reflection
    def reflection_condition
      ref = reflection
      through_reflection = ref && (ref.source_reflection || ref.through_reflection)
      main_condition = extract_conditions_from_reflection ref
      through_condition = extract_conditions_from_reflection through_reflection

      sql = [main_condition, through_condition].reject(&:blank?).join(' AND ')

      sql = sql.gsub(table_name, quoted_table_name).gsub(/\#\{([a-z0-9_]+)\}/, 'quoted_table_name.\1').\
        gsub('quoted_table_name', parent.quoted_table_name) unless sql.blank?
    end

    def extract_conditions_from_reflection(ref)
      if !ref
        nil
      elsif ref.respond_to?(:scope)
        scope = ref.scope
        begin
          klass.send(:sanitize_sql, scope && scope.call)
        rescue NameError => e
          unless e.message.include?('extending')
            relation = klass.instance_eval(&scope)
            if relation.respond_to? :where_values
              klass.send(:sanitize_sql, relation.where_values.collect(&:to_sql).join(' AND '))
            else
              sql = relation.to_sql
              sql = sql.split('WHERE')[1..-1].join('WHERE').strip if sql
              sql
            end
          end
        end
      else
        klass.send(:sanitize_sql, ref.options[:conditions])
      end
    end
    
    # returns the type condition for the STI-Class
    # when the klass decends not from ActiveRecord::Base
    def type_condition_for_sti
      unless parent_klass.descends_from_active_record?
        parent_klass.send(:sanitize_sql, parent_klass.inheritance_column => parent_klass.to_s).\
          gsub(parent.table_name, parent.quoted_table_name)
      end
    end
    
    # merge the sql condition strings from the parents
    # the reflection_condition and the type_condition for sti are included, too
    def where_conditions_sum
      where_conditions = []

      where_conditions << parent.send(:reflection_condition)
      where_conditions << type_condition_for_sti
      where_conditions << condition_sql

      where_conditions.reject!(&:blank?)
      unless where_conditions.empty?
        "(#{where_conditions.join(') AND (')})"
      end
    end
    
    # merge the sql condition strings from the parents
    # the reflection_condition and the type_condition for sti are included, too
    def and_where_conditions_sum
      if sql = where_conditions_sum
        " AND (#{sql})"
      end
    end

    # merge the sql condition strings from the parents
    # the reflection_condition and the type_condition for sti are included, too
    def sql_conditions_sum
      sql = parent.to_sort_condition

      if sql_affix = where_conditions_sum
        sql = "(#{sql}) AND #{sql_affix}"
      end

      sql
    end
    
    # joins all associated collection strings for to one string as sql
    def sql_column_name_condition
      if parent.reflection
        sql_clomn_name_condition_with_reflection
      else
        sql_clomn_name_condition_without_reflection
      end
    end

    def sql_clomn_name_condition_with_reflection
      if limit == DEFAULT_LIMIT
        sql_clomn_name_condition_with_reflection_and_without_group_concat
      else
        sql_clomn_name_condition_with_reflection_and_with_group_concat
      end
    end

    def sql_clomn_name_condition_with_reflection_and_with_group_concat
      table_column = "#{parent.quoted_table_name}.#{column_name}"
      column = klass.columns_hash[column_name]
      order = sort ? " #{sort}" : ''

      table_column_for_group_concat = if column.text?
        "LPAD(#{table_column}, #{column.limit}, ' ')"
      else
        table_column
      end

      "(SELECT GROUP_CONCAT(#{table_column_for_group_concat} " +
      "ORDER BY #{table_column}#{order} SEPARATOR ' ') " + \
      "FROM #{table_name} #{parent.quoted_table_name} WHERE #{sql_conditions_sum} " +
      "LIMIT #{limit})#{order}"
    end

    def sql_clomn_name_condition_with_reflection_and_without_group_concat
      table_column = if column_name.include?(parent.table_name) 
        column_name.gsub(parent.table_name, parent.quoted_table_name)
      else
        "#{parent.quoted_table_name}.#{column_name}"
      end
      
      sort_sql = sort.blank? ? '' : " #{sort}"
      order = sort && @with_order ? sort_sql : ''
      count_or_sum = count || sum
      limit_sql = count_or_sum ? '' : " LIMIT #{limit}"

      column = if sum
        "SUM(#{table_column})"
      elsif count
        "COUNT(#{table_column})"
      else
        table_column
      end
      
      order_by = if count_or_sum
        ''
      elsif custom_sort
        " ORDER BY #{custom_sort} #{limit_sql}"
      elsif inner_sort
        " ORDER BY #{table_column} #{inner_sort}#{limit_sql}"
      else
        " ORDER BY #{table_column}#{sort_sql}#{limit_sql}"
      end

      "(SELECT #{column} FROM #{table_name} #{parent.quoted_table_name} " +
      "WHERE #{sql_conditions_sum}#{order_by})#{order}"
    end

    def sql_clomn_name_condition_without_reflection
      table_column = if column_name.include?(parent.table_name) 
        column_name.gsub(parent.table_name, parent.quoted_table_name)
      else
        "#{parent.quoted_table_name}.#{column_name}"
      end
      [table_column, sort].compact.join(' ')
    end
    
    def sql_by_belongs_to_polymorhic_reflection
      sql = "#{quoted_table_name}.#{child.reflection_name}_type = ? AND " + \
        "#{quoted_table_name}.#{child.reflection_name}_id IN " + \
      
      sql + sql_part_for_belongs_to_reflection
    end
    
    # returns an reflection sql for a 
    # belongs to reflection
    #
    # the sql_conditions_sum are included
    def sql_by_belongs_to_reflection
      sql = "#{quoted_table_name}.#{child.klass.primary_key} IN "
      sql + sql_part_for_belongs_to_reflection
    end

    def sql_part_for_belongs_to_reflection
      if parent && parent.parent
        sql_part_for_belongs_to_reflection_with_parent_reflection
      else
        sql_part_for_belongs_to_reflection_without_parent_reflection
      end
    end

    def sql_part_for_belongs_to_reflection_with_parent_reflection
      "(SELECT #{parent.quoted_table_name}.#{primary_key_name} " + \
        "FROM #{parent.table_name} #{parent.quoted_table_name} WHERE #{sql_conditions_sum})"
    end

    def sql_part_for_belongs_to_reflection_without_parent_reflection
      "(#{parent.quoted_table_name}.#{primary_key_name}) #{and_where_conditions_sum}"
    end
    
    # returns an reflection sql for a 
    # has and belongs to reflection
    #
    # the sql_conditions_sum are included
    def sql_by_has_and_belongs_to_many_reflection
      sql = "#{quoted_table_name}.#{child.klass.primary_key} " + 
        "IN (SELECT #{quoted_join_table}.#{association_foreign_key} " + 
          "FROM #{join_table} #{quoted_join_table} " + 
          "WHERE #{quoted_join_table}.#{primary_key_name}"

      if parent && parent.parent
        "#{sql} IN (SELECT #{parent.quoted_table_name}.id " +
          "FROM #{parent.table_name} #{parent.quoted_table_name} " +
          "WHERE #{sql_conditions_sum}))"
      else
        "#{sql} IN (#{parent.quoted_table_name}.#{parent_klass.primary_key})) #{and_where_conditions_sum}"
      end
    end
    
    # returns an reflection sql for a 
    # has many reflection
    #
    # the sql_conditions_sum are included
    def sql_by_has_many_reflection
      if reflection.through_reflection && reflection.through_reflection.macro == :belongs_to
        sql_by_has_many_through_belongs_to_reflection
      elsif reflection.through_reflection && reflection.through_reflection.macro != :belongs_to
        sql_by_has_many_through_has_many_reflection
      elsif reflection.options[:as]
        sql_by_has_many_polymorphic_reflection
      else
        sql_by_has_many_normal_reflection
      end
    end

    def through_reflection?
      reflection.through_reflection || reflection.source_reflection
    end
    alias through_reflection through_reflection?
    
    # returns an reflection sql for a 
    # has many normal reflection
    #
    # the sql_conditions_sum are included
    #
    # sub method for sql_by_has_many_reflection
    def sql_by_has_many_normal_reflection
      if parent && parent.parent
      "#{quoted_table_name}.#{primary_key_name} " + \
        "IN (SELECT #{parent.quoted_table_name}.#{klass.primary_key} " + \
          "FROM #{parent.table_name} #{parent.quoted_table_name} WHERE #{sql_conditions_sum})"
      else
        "#{quoted_table_name}.#{primary_key_name} " +
          "IN (#{parent.quoted_table_name}.#{parent_klass.primary_key}) #{and_where_conditions_sum}"
      end
    end
    
    # returns an reflection sql for a 
    # has many through reflection
    #
    # the sql_conditions_sum are included
    #
    # sub method for sql_by_has_many_reflection
    def sql_by_has_many_through_belongs_to_reflection
      refl = reflection.through_reflection
      through_primary_key = refl.respond_to?(:foreign_key) ? refl.foreign_key : refl.primary_key_name

      sql = "#{quoted_table_name}.#{through_primary_key} " + 
        "IN (SELECT #{quoted_join_table}.#{child.klass.primary_key} " + 
          "FROM #{join_table} #{quoted_join_table} " + 
          "WHERE #{quoted_join_table}.#{child.klass.primary_key}"

      if parent && parent.parent
        "#{sql} IN (SELECT #{parent.quoted_table_name}.id " +
          "FROM #{parent.table_name} #{parent.quoted_table_name} " +
          "WHERE #{sql_conditions_sum}))"
      else
        "#{sql} IN (#{parent.quoted_table_name}.#{through_primary_key})) #{and_where_conditions_sum}"
      end
    end
    
    # returns an reflection sql for a 
    # has many through has_many reflection
    #
    # the sql_conditions_sum are included
    #
    # sub method for sql_by_has_many_reflection
    def sql_by_has_many_through_has_many_reflection
      primary_key_name = if through_reflection.respond_to?(:foreign_key)
        through_reflection.foreign_key
      else 
        through_reflection.primary_key_name
      end

      sql = "#{quoted_table_name}.#{child.klass.primary_key} " + 
        "IN (SELECT #{quoted_join_table}.#{association_foreign_key} " + 
          "FROM #{join_table} #{quoted_join_table} " + 
          "WHERE #{quoted_join_table}.#{primary_key_name}"

      if parent && parent.parent
        "#{sql} IN (SELECT #{parent.quoted_table_name}.id " +
          "FROM #{parent.table_name} #{parent.quoted_table_name} " +
          "WHERE #{sql_conditions_sum}))"
      else
        "#{sql} IN (#{parent.quoted_table_name}.#{child.klass.primary_key})) #{and_where_conditions_sum}"
      end
    end
    
    # returns an reflection sql for a 
    # has many normal reflection
    #
    # the sql_conditions_sum are included
    #
    # sub method for sql_by_has_many_reflection
    def sql_by_has_many_polymorphic_reflection
      sql =  "#{quoted_table_name}.#{reflection.options[:as]}_type = '#{parent_klass.base_class}' AND " +
        "#{quoted_table_name}.#{reflection.options[:as]}_id " +
        "IN "
      if parent && parent.parent
        "#{sql} (SELECT #{parent.quoted_table_name}.#{klass.primary_key} " + \
          "FROM #{parent.table_name} #{parent.quoted_table_name} WHERE #{sql_conditions_sum})"
      else
        "#{sql} (#{parent.quoted_table_name}.#{parent_klass.primary_key}) #{and_where_conditions_sum}"
      end
    end
    
    # returns an reflection sql for a 
    # has one reflection
    #
    # the sql_conditions_sum are included
    #
    # has one is a has many reflection
    # and this sql_string are returned
    def sql_by_has_one_reflection
      sql_by_has_many_normal_reflection
    end
    
    # quotes the given table name
    # this is needed, because mysql overwrite table_name.column in subselects, too
    # example: "articles_100"
    def quote_table_name(unquoted_table_name, index=condition_index)
      index != start_index ? "#{index}_#{unquoted_table_name}" : unquoted_table_name
    end

    ONE_REFLECTION_MACROS = [:has_one, :belongs_to]
    def one_reflection?
      ONE_REFLECTION_MACROS.include? reflection.macro.to_sym if reflection
    end
    
    def many_reflection?
      !ONE_REFLECTION_MACROS.include?(reflection.macro.to_sym) if reflection
    end

    def one_reflection_conditions
      one_reflection? ? "" : ''
    end
  end
end
