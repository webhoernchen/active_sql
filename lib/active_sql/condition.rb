# ActiveSql::Condition is a libary to write complicated sql conditions in Ruby syntax
# 
# You can set the conditions and 
# use the method "to_record_condition" to use the conditions 
# in the conditions options of the ActiveRecord.find.
# Of course you can use all other options, too.
# Such like :include or :order, ...
# 
# Examples:
# +All conditions joined with and+:
#   condition = ActiveSql::Condition.new(:klass => Product)
#   condition.name.include('TV')
#   condition.manufacturer.name.begins_with('Grundig')
#   condition.to_record_conditions
#   => ["LOWER(products.name) like LOWER(?) AND products.manufacturer_id IN (SELECT manufacturers_1.id FROM manufacturers manufacturers_1 WHERE LOWER(manufacturers_1.name) LIKE LOWER(?))", "%TV%", "Grundig%]
#   
# +All conditions joined with or+:
#   condition = ActiveSql::Condition.new(:klass => Product, :sql_join => :or)
#   condition.name.include('TV')
#   condition.manufacturer.name.begins_with('Grundig')
#   condition.to_record_conditions
#   => ["LOWER(products.name) like LOWER(?) OR products.manufacturer_id IN (SELECT manufacturers_1.id FROM manufacturers manufacturers_1 WHERE LOWER(manufacturers_1.name) LIKE LOWER(?))", "%TV%", "Grundig%]
#
# +To Easer use this functionality use the find_by_active_sql method of the RecordClass+:
# +Return 1 record+
# products = Product.find_by_active_sql(:include => :manufacturers) do |record|
#   record.name.include('TV')
#   record.manufacturer.name.begins_with('Grundig')
# end
# 
# +To Easer use this functionality use the find_all_by_active_sql method of the RecordClass+:
# +Return an Array of Records+
# products = Product.find_all_by_active_sql(:include => :manufacturers) do |record|
#   record.name.include('TV')
#   record.manufacturer.name.begins_with('Grundig')
# end
#
# +Of course you can join the conditions with or+:
# products = Product.find_by_active_sql(:include => :manufacturers, :sql_join => :or) do |record|
#   record.name.include('TV')
#   record.manufacturer.name.begins_with('Grundig')
# end
#
# +And the greatest magic is use :or and :and in groups+
# products = Product.find_all_by_active_sql(:include => :manufacturers, :order => :name, :sql_join => :or) do |record|
#   record.name.include('TV')
#   record.manufacturer(:and) do |manufacturer|
#     manufacturer.name.begins_with('Grundig')
#     manufacturer.addresses(:or) do |address|
#       address.city.begins_with('Nürn')
#       address.postcode.includes(90)
#     end
#   end
# end
# 
# +When you want to search in a column which is a reserved name in ruby or rails 
# use the condition_for method to create this condition+
# products = Product.find_all_by_active_sql(:include => :manufacturers, :order => :name) do |record|
#   record.name.include('TV')
#   record.condition_for(:type).include('test')
# end
# 
#

module ActiveSql
  class TypeError < StandardError; end
  class SqlJoinError < StandardError; end
  class PolymorphicError < StandardError; end
  class ScopeError < StandardError; end

  class Condition
    
    VALID_SQL_JOINS = [(DEFAULT_SQL_JOIN = 'and'), 'or']
    
    # All Attributes are protected
    # because it is not needed to change this attributes outside this class
    protected
    attr_accessor :klass, :cond_values, 
                  :condition_methods, :column_name, :table_column_sql,
                  :childs_hash, :reflection, :parent, :condition_index,
                  :type_condition
    
    attr_reader :sql_join
    attr_writer :table_name
    
    public
    # Only 1 Argument is needed to initialize this Condition
    # All other Arguments are used intern
    # 
    # options can be:
    # +klass+: (+required+) the RecordClass to create the condition
    def initialize(options)
      self.klass = options[:klass] || options[:reflection].klass
      
      self.column_name = options[:column_name]
      self.table_column_sql = options[:table_column_sql]
      self.childs_hash = ActiveSupport::OrderedHash.new
      self.reflection = options[:reflection]
      self.parent = options[:parent]
      self.condition_methods = []
      self.cond_values = []
      self.condition_index = options[:condition_index] || 1000
      self.sql_join = (options[:sql_join] || parent && parent.sql_join || DEFAULT_SQL_JOIN).to_s
      self.type_condition = options[:type_condition]
      self.table_name = options[:table_name] if options[:table_name]
    end

    def start_index
      @start_index ||= parent ? parent.start_index : condition_index
    end
    
    # the value of the column starts with this +text+
    def starts_with(text)
      where_like("#{text}%")
    end
    alias start_with starts_with
    alias begin_with starts_with
    alias begins_with starts_with
    
    # the value of the column starts not with this +text+
    def starts_not_with(text)
      where_not_like("#{text}%")
    end
    alias start_not_with starts_not_with
    alias begin_not_with starts_not_with
    alias begins_not_with starts_not_with
    alias not_begin_with starts_not_with
    
    # the value of the column ends with this +text+
    def ends_with(text)
      where_like("%#{text}")
    end
    alias end_with ends_with

    def like(text)
      where_like(text)
    end
    alias match like

    def not_like(text)
      where_not_like(text)
    end
    
    # the value of the column ends with this +text+
    def ends_not_with(text)
      where_not_like("%#{text}")
    end
    alias end_not_with ends_not_with
    alias not_end_with ends_not_with

    def included_in(sql_string)
      where("IN (SELECT (#{sql_string}))", [])
    end

    def collect(&block)
      options = {:quoted_table_name => quoted_table_name, :klass => klass}

      condition = ActiveSql::SortCondition.new(options)
      sort_condition = yield(condition)
      sort_condition.to_sort_condition(false)
    end
    
    # the value of the column includes this +value+
    #
    # orgit merge remote branch
    #
    # the value of the column is in this Array
    def includes(value)
      if value.is_a?(Array)
        where_in(value)
      else
        where_like("%#{value}%")
      end
    end
    alias include includes
    
    # the value of the column includes not this +value+
    #
    # or
    #
    # the value of the column is not in this Array
    def not_includes(value)
      if value.is_a?(Array)
        where_not_in(value)
      else
        where_not_like("%#{value}%")
      end
    end
    alias not_include not_includes
    alias includes_not not_includes
    
    # the value of the column is equal +value+
    def is_equal(value)
      value.nil? ? where('IS ?', value) : where('<=> ?', value)
    end
    alias == is_equal
    alias equals is_equal
    alias is is_equal
    
    # the value of the column is not equal +value+
    def is_not_equal(value)
      value.nil? ? where('IS NOT ?', value) : where('<> ?', value)
    end
    alias equals_not is_not_equal
    alias is_not is_not_equal
    alias does_not_equal is_not_equal

    def is_nil
      is nil
    end
    alias is_null is_nil

    def is_not_nil
      is_not nil
    end
    alias is_not_null is_not_nil

    def is_empty
      is ''
    end

    def is_not_empty
      is_not ''
    end

    def is_blank
      con = create_or_find_child_by_name(column_name, :or, {}, 1024)
      con.is_empty
      con.is_nil
    end

    def is_not_blank
      con = create_or_find_child_by_name(column_name, :and, {}, 2048)
      con.is_not_empty
      con.is_not_nil
    end
    
    # the value of the column is greater than +value+
    def greater_than(value)
      where('> ?', value)
    end
    alias > greater_than
    
    # the value of the column is lower than +value+
    def is_lower_than(value)
      where('< ?', value)
    end
    alias lower_than is_lower_than
    alias less_than is_lower_than
    alias < is_lower_than
    
    # the value of the column is greater than or euqal +value+
    def greater_than_or_equal(value)
      where('>= ?', value)
    end
    alias >= greater_than_or_equal
    alias greater_than_or_equal_to greater_than_or_equal
    
    # the value of the column is lower than or equal +value+
    def lower_than_or_equal(value)
      where('<= ?', value)
    end
    alias <= lower_than_or_equal
    alias less_than_or_equal lower_than_or_equal
    alias less_than_or_equal_to lower_than_or_equal
    
    # the value of the column is between +value+, +value+
    def between(*values)
      where('BETWEEN ? AND ?', values.flatten)
    end
    
    # the value of the column is not between +value+, +value+
    def not_between(*values)
      where('NOT BETWEEN ? AND ?', values.flatten)
    end

    def max(&block)
      calculation 'max', :sort => 'DESC', &block
    end

    def min(&block)
      calculation 'min', :sort => 'ASC', &block
    end

    def sum(&block)
      calculation 'sum', :sum => true, &block
    end

    def count(&block)
      calculation 'count', :count => true, &block
    end
    
    # returns the record conditions as array
    # all conditions are merged in 1 Array
    # can be used directly with the conditions option from ActiveRecord::Base
    # 
    # [sql_string, value_1, value_2, ...]
    # example: ["articles.price > ? AND articles.sales_tax_rate <=> ?", 200, 7]
    def to_record_conditions
      if reflection
        [send("sql_by_#{reflection.macro}_reflection")] + sql_values
      else
        [sql_conditions_sum] + sql_values
      end
    end
    
    # the default method missing is overwritten here to accepts the columns 
    # for the condition in a easily understanding api
    def method_missing(name, *args, &block)
      # check if a child condition for these arguments already existis 
      # or create a new one
      # the child condition will be returned or as argument in a block
      options = args.detect {|v| v.is_a?(Hash)} || {}
      args.delete(options)
      if child = create_or_find_child_by_name(name, args.first, options, block_given? && block.object_id)
        if block_given?
          yield(child)
        else
          child
        end
      elsif klass.respond_to? name
        by_scope unscoped_klass.send(name, *args)
      else
        super
      end
    end
    
    # use condition_for to set conditions for a table column 
    # which has the same name such as a reserved word in ruby or rails
    # 
    # the api is the same such as a normal method
    #
    # example:
    # products = Product.find_all_by_active_sql do |record|
    #   record.condition_for(:type, :or) do |type|
    #     type.include('test')
    #   end
    # end
    alias condition_for method_missing

    def by_scope(scope)
      raise ScopeError, 'no scope given' unless scope && scope.respond_to?(:where_or_scoped)

      wrapped_scope = scope.where_or_scoped({})

      sql_condition = if wrapped_scope.respond_to? :arel
        sql = extract_conditions_from_arel_relation wrapped_scope
        if sql
          sql = sql.gsub("FROM #{table_name}", 'FROM_TABLE').
          gsub(Regexp.new("(\\`|\"|\\(|\\ )#{table_name}"), '\1' + "#{quoted_table_name}").
          gsub('FROM_TABLE', "FROM #{table_name}")
        else
          by_empty_scope_or_relation
        end
      elsif wrapped_scope.respond_to?(:current_scoped_methods)
        by_active_record_scope wrapped_scope
      else
        raise 'unsupported'
      end
      
      self.condition_methods << sql_condition
    end

    def by_custom_column(sql)
      index = ['custom_sql', object_id].join('__')
      sql = sql.gsub(table_name, quoted_table_name)
      sql = klass.send(:sanitize_sql, sql)
      childs_hash[index] = self.class.new({:klass => self.klass, :parent => self, 
        :table_column_sql => sql, :condition_index => condition_index, :sql_join => sql_join})
    end

    def by_subgroup(join, &block)
      cond = self.class.new({:klass => self.klass, :condition_index => condition_index, 
        :sql_join => join, :table_name => quoted_table_name})
      
      yield(cond)
      
      sql = cond.to_record_conditions
      sql = klass.send(:sanitize_sql, sql)

      self.condition_methods << sql
    end

    def any(&block)
      if block_given?
        yield self
      else
        self
      end
    end
    alias any_of any

    def pk
      condition_for primary_key
    end
    
    protected
    def unscoped_klass
      @unscoped_klass ||= if klass.respond_to? :unscoped
        klass.unscoped
      else
        klass
      end
    end

    def sql_join=(value)
      if VALID_SQL_JOINS.include?(value)
        @sql_join = value
      else
        raise ActiveSql::SqlJoinError, "Sql join can only be one of the following list '#{VALID_SQL_JOINS.join("', '")}'. But was #{value}"
      end
    end
    
    # childs are child conditions
    # childs are needed to create the condition tree for arguments
    def childs
      childs_hash.values
    end
    
    # returns the table name from the klass
    def table_name
      @table_name ||= klass.table_name
    end
    
    def quoted_table_name
      @quoted_table_name ||= quote_table_name table_name
    end
    
    # returns the table_name from the parent condition
    def parent_table_name
      parent.table_name
    end
    
    # returns the primary key from the parent condition
    def parent_primary_key
      parent.primary_key
    end
    
    def quoted_parent_table_name
      @quoted_parent_table_name ||= parent.quoted_table_name
    end
    
    # returns the primary key from this condition
    def primary_key
      klass.primary_key
    end
    
    def primary_key_name
      through_reflection = reflection.through_reflection
      refl = if through_reflection && through_reflection.macro != :belongs_to
        through_reflection
      else
        reflection.source_reflection || through_reflection || reflection
      end
      refl.respond_to?(:foreign_key) ? refl.foreign_key : refl.primary_key_name 
    end
    
    def join_table
      if table = reflection.options[:join_table] 
        table
      elsif reflection.through_reflection# && reflection.through_reflection.macro != :belongs_to 
        reflection.through_reflection.table_name
      elsif reflection.respond_to?(:join_table)
        reflection.join_table
      end
    end
    
    def quoted_join_table
      @quoted_join_table ||= quote_table_name join_table
    end
    
    def association_foreign_key
      srefl = reflection.source_reflection
      if reflection.macro.to_sym != :has_and_belongs_to_many && srefl
        srefl.respond_to?(:foreign_key) ? srefl.foreign_key : srefl.primary_key_name
      else
        reflection.association_foreign_key 
      end
    end
    
    # each condition has an own index to identify the condition for later use
    # this method calculates the prefix of this index
    def condition_name_prefix
      @condition_name_prefix ||=
        "#{(parent ? parent.condition_name_prefix : '')}_#{klass.to_s.underscore}_#{sql_join}"
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

      sql.gsub(table_name, quoted_table_name).gsub(/\#\{([a-z0-9_]+)\}/, 'parent_table_name.\1').\
        gsub('parent_table_name', quoted_parent_table_name) unless sql.blank?
    end

    def extract_conditions_from_reflection(ref)
      if !ref
        nil
      elsif ref.respond_to?(:scope)
        if scope = ref.scope
          if scope.respond_to?(:options)
            klass.send(:sanitize_sql, scope.options[:where])
          else
            begin
              sql = klass.instance_exec(&scope)
              if sql.is_a?(String)
                sql
              elsif sql.respond_to? :arel
                extract_conditions_from_arel_relation sql
              else
                klass.send :sanitize_sql, sql.where_values.collect(&:to_sql) + sql.where_values_hash.values
              end
            rescue NoMethodError => e
              unless e.message.include?('extending')
                raise e
              end
            end
          end
        end
      else
        klass.send(:sanitize_sql, ref.options[:conditions])
      end
    end

    def extract_conditions_from_arel_relation(relation)
      arel = relation.arel
      if where_sql = arel.where_sql
        values = relation.where_values_hash.values.flatten

	where_sql = where_sql.strip.gsub(/(\s)\$[0-9]+(\s|$)/, '\1?\2')
        count_scanned_values = where_sql.scan(/\?/).size
        
        if !count_scanned_values.zero? && count_scanned_values != values.size
          values = []
          where_sql = relation.to_sql
        end
        
        where_sql = where_sql.split('WHERE')[1..-1].join('WHERE').strip

        if values.empty? || count_scanned_values.zero?
          where_sql
        else
          klass.send :sanitize_sql, [where_sql] + values
        end
      end
    end
    
    # returns the type condition for the STI-Class
    # when the klass decends not from ActiveRecord::Base
    def type_condition_for_sti
      if !klass.descends_from_active_record? && type_condition != false
        sti_condition_array = if (sti_condition = (type_condition || klass.to_s)).include?('%')
          ["#{quoted_table_name}.#{klass.inheritance_column} LIKE ?", sti_condition]
        else
          ["#{quoted_table_name}.#{klass.inheritance_column} = ?", sti_condition]
        end
        klass.send(:sanitize_sql, sti_condition_array)
      end
    end
    
    private
    def merge_conditions(*conditions)
      conditions = conditions.flatten

      conditions = conditions.collect do |condition|
        unless condition.blank?
          condition = condition.to_sql if condition.respond_to?(:to_sql)
          klass.send(:sanitize_sql, condition)
        end
      end

      conditions.reject!(&:blank?)

      unless conditions.empty?
        "(#{conditions.join(') AND (')})"
      end
    end

#    def by_active_record_relation_hash(relation)
#      if (where_values_hash = relation.where_values_hash).blank?
#        by_active_record_relation relation
#      elsif relation.respond_to?(:where_values) && (where_values = relation.where_values).blank?
#        by_empty_scope_or_relation
#      else
#        sql = if relation.respond_to? :to_sql
#          relation.to_sql.split('WHERE')[1..-1].join('WHERE').strip
#        else
#          cond = where_values.collect(&:to_sql) + where_values_hash.values
#          klass.send(:sanitize_sql, cond)
#        end
#      
#        unless sql.blank?
#          sql.gsub("FROM #{table_name}", 'FROM_TABLE').
#            gsub(Regexp.new("(\\`|\\(|\\ )#{table_name}"), '\1' + "#{quoted_table_name}").
#            gsub('FROM_TABLE', "FROM #{table_name}")
#        end
#      end
#    end

#    def by_active_record_relation(relation)
#      if relation.respond_to? :to_sql
#        sql = relation.to_sql.to_s.split('WHERE')[1..-1].join('WHERE').strip.
#          gsub("FROM #{table_name}", 'FROM_TABLE').
#          gsub(Regexp.new("(\\`|\\(|\\ )#{table_name}"), '\1' + "#{quoted_table_name}").
#          gsub('FROM_TABLE', "FROM #{table_name}")
#        sql.blank? ? nil : sql
#      elsif (where_values = relation.where_values).blank?
#        by_empty_scope_or_relation
#      else
#        sql = merge_conditions where_values
#        sql.to_s.gsub("FROM #{table_name}", 'FROM_TABLE').
#          gsub(Regexp.new("(\\`|\\(|\\ )#{table_name}"), '\1' + "#{quoted_table_name}").
#          gsub('FROM_TABLE', "FROM #{table_name}")
#      end
#    end

    def by_active_record_scope(scope)
      scoped_methods = scope.send(:current_scoped_methods)

      if (find_scope_conditions = scoped_methods[:find] || {}).blank? || find_scope_conditions[:conditions].blank?
        by_empty_scope_or_relation
      else
        find_conditions = find_scope_conditions[:conditions] || {}

        sql = klass.send(:sanitize_sql, find_conditions)
        sql.to_s.gsub("FROM #{table_name}", 'FROM_TABLE').
          gsub(Regexp.new("(\\`|\\(|\\ )#{table_name}"), '\1' + "#{quoted_table_name}").
          gsub('FROM_TABLE', "FROM #{table_name}")
      end
    end

    def by_empty_scope_or_relation
      "#{quoted_table_name}.#{primary_key} = #{quoted_table_name}.#{primary_key}"
    end

    def calculation(type, options, &block)
      if block_given?
        options = {:quoted_table_name => quoted_table_name, :klass => klass}.merge(options)

        condition = ActiveSql::SortCondition.new(options)
        sort_condition = yield condition
        sort_condition = sort_condition.by_pk if sort_condition.send(:reflection)
        index = [type, sort_condition.full_name, sort_condition.object_id].join('__')
        column = sort_condition.to_sort_condition(false)

        childs_hash[index] = self.class.new({:klass => self.klass, :parent => self, 
          :table_column_sql => column, :condition_index => condition_index, :sql_join => sql_join})
      else
        name = reflection.name
        parent.childs_hash.delete_if {|k, v| v.object_id == object_id }
        parent.count {|r| r.send name }
      end
    end

    # create a like condition for the given value
    def where_like(value)
      where('LIKE ?', value)
    end

    # create a IN-condition for the given values (Array)
    def where_in(values)
      where('IN (?)', [values])
    end

    # create a NOT IN-condition for the given values (Array)
    def where_not_in(values)
      where('NOT IN (?)', [values])
    end
    
    # create a not like condition for the given value
    def where_not_like(value)
      where('NOT LIKE ?', value)
    end
    
    # create the where statement for the given sql_condition_method and value
    # +sql_condition_methods+: can be "LIKE", "<", ...
    # +value+: the value for this condition
    #
    # returns the sql string
    # the column and the value are marked with LOWER when the value is not nil
    def where(sql_condition_method, value)
      if column_name.blank? && table_column_sql.blank?
        if reflection
          if value.is_a? klass
            condition_for(klass.primary_key) == value.send(klass.primary_key)
          else
            message = "#{klass.to_s}(##{klass.object_id}) expected, got #{value.inspect} which is an instance of #{value.class}(##{value.class.object_id})"
            raise ActiveSql::TypeError, message
          end
        else column_name.blank? && table_column_sql.blank?
          raise ActiveSql::TypeError, "Only columns from tables can be checked"
        end
      else
        table_column = if table_column_sql.blank?
          "#{quoted_table_name}.#{column_name}"
        else
          table_column_sql
        end
        
        if value.is_a?(self.class)
          value.parent.childs_hash.delete_if {|k, v| v.object_id == value.object_id }
          column_key = "#{value.quoted_table_name}.#{value.column_name}"
          sql_condition_method = sql_condition_method.gsub('?', column_key)
        end
        
        self.condition_methods << "#{table_column} #{sql_condition_method}"
        
        if value.is_a?(Array)
          value.each {|v| self.cond_values << v }
        elsif !value.is_a?(self.class)
          self.cond_values << value
        end
      end
    end
    
    # create or find the child condition for the given args
    # +name+: can be a column name or a reflection name of the given klass
    # +child_sql_join+: when with the child block the child sql join is given, 
    #                   then all childs are joined with the given join (:and or :or)
    #
    # when the method find a child through the generated child_condition_index_for_name
    # => then the child_condition will be returned
    #
    # when the method find no child and the name is a reflection of the given klass,
    # => then a new child_condition will be crated and returned for the reflection
    #
    # when the method find no child and the name is a column of the given klass,
    # => then a new child_condition will be crated and returned for the column name
    #
    # returns nil if 
    # * no child were found, 
    # * no reflection were found or
    # * no column name were found
    def create_or_find_child_by_name(name, child_sql_join, options={}, block_id=nil)
      child_sql_join ||= (options.symbolize_keys[:sql_join] || sql_join)
      child_condition_index_name = child_condition_index_for_name(name, child_sql_join, block_id)
      
      if child = childs_hash[child_condition_index_name]
        child
      elsif reflection_from_klass = klass.reflect_on_association(name)
        childs_hash[child_condition_index_name] = create_child_by_reflection(reflection_from_klass, child_sql_join, options)
      elsif klass.column_names.include?(name.to_s)
        childs_hash[child_condition_index_name] = create_child_by_column(name.to_s, child_sql_join)
      elsif klass.respond_to?(:attribute_alias?) && klass.attribute_alias?(name)
        alias_name = klass.attribute_alias name
        create_or_find_child_by_name alias_name, child_sql_join, options, block_id
      else
        nil
      end
    end
    
    # creates a new child condition for a reflection
    # +reflection+: Instance of a reflection of the reflection hash from the given klass
    # +child_sql_join+: when with the child block the child sql join is given, 
    #                   then all childs are joined with the given join (:and or :or)
    def create_child_by_reflection(reflection, child_sql_join, options)
      klass = options[:is] ? options[:is].to_s.classify.constantize : nil
      klass = options[:klass] if klass.nil? && options[:klass]
      
      raise ActiveSql::PolymorphicError,
        "Need option :is => class_name for a polymorphic belongs_to reflection" \
        if reflection.options[:foreign_type] && klass.nil? && ONE_REFLECTION_MACROS.include?(reflection.macro)

      self.class.new({:reflection => reflection, 
                      :parent => self,
                      :condition_index => condition_index.next,
                      :sql_join => child_sql_join,
                      :type_condition => options[:type],
                      :klass => klass})
    end
    
    # creates a new child condition for a column name
    # +name+: column name of the given klass
    # +child_sql_join+: when with the child block the child sql join is given, 
    #                   then all childs are joined with the given join (:and or :or)
    def create_child_by_column(name, child_sql_join)
      self.class.new({:klass => self.klass,
                      :parent => self, 
                      :column_name => name,
                      :condition_index => condition_index,
                      :sql_join => child_sql_join,
                      :table_name => condition_index == start_index ? table_name : nil})
    end
    
    # returns a hash with the given sql_conditions and values as Array from the own column
    # example: {:sql_conditions => ["articles.price > ?", "articles.sales_tax_rate = ?"]
    #          {:values => [200, 7]
    def record_conditions_from_own_column
      @record_conditions_from_own_column ||= {:sql_conditions => condition_methods, 
                                              :values => cond_values}
    end
    
    # returns a hash with the given sql_conditions and values as Array from the childs
    # example: {:sql_conditions => ["articles.price > ?", "articles.sales_tax_rate = ?"]
    #          {:values => [200, 7]
    def record_conditions_from_childs
      if @record_conditions_from_childs
        @record_conditions_from_childs
      else
        sql_conditions_from_childs = []
        values_from_childs = []
        childs.each do |child|
          cond = child.to_record_conditions
          sql_conditions_from_childs << cond.first
          values_from_childs += cond[1..-1]
        end

        @record_conditions_from_childs ||= {:sql_conditions => sql_conditions_from_childs, 
                                            :values => values_from_childs}
      end
    end
    
    # merge the sql condition strings from the own column and
    # from the childs
    # the conditions are join by the given sql_join
    # the reflection_condition and the type_condition for sti are included, too
    def sql_conditions_sum
      sql = (record_conditions_from_own_column[:sql_conditions] + \
        record_conditions_from_childs[:sql_conditions]).reject(&:blank?).join(") #{sql_join.upcase} (")
      sql = "(#{sql})" unless sql.blank?

      if sql_affix_reflection = reflection_condition
        sql = "((#{sql}) AND #{sql_affix_reflection})"
      end
      
      if (sql_affix_sti = type_condition_for_sti) && condition_index != start_index && reflection
        sql = "((#{sql}) AND #{sql_affix_sti})"
      end

  #    if one_reflection?
  #      sql = "(SELECT #{sql} LIMIT 1)"
  #    end
      
      sql
    end
    
    # merge the sql_values from the own column and from the childs
    # returns an Array of values
    def sql_values
      record_conditions_from_own_column[:values] + \
        record_conditions_from_childs[:values]
    end
    
    # returns an reflection sql for a 
    # belongs to reflection
    #
    # the sql_conditions_sum are included
    def sql_by_belongs_to_reflection
      if reflection.options[:foreign_type]
        sql_by_belongs_to_polymorhic_reflection
      else
        sql_by_belongs_to_normal_reflection
      end
    end

    def sql_by_belongs_to_polymorhic_reflection
      self.cond_values << klass.base_class.to_s
      "#{quoted_parent_table_name}.#{reflection.name}_type = ? AND " + \
        "#{quoted_parent_table_name}.#{reflection.name}_id " + \
          "IN (SELECT #{quoted_table_name}.#{primary_key} FROM #{table_name} #{quoted_table_name} WHERE #{sql_conditions_sum})"
    end

    def sql_by_belongs_to_normal_reflection
      "#{quoted_parent_table_name}.#{primary_key_name} " + \
          "IN (SELECT #{quoted_table_name}.#{primary_key} FROM #{table_name} #{quoted_table_name} WHERE #{sql_conditions_sum})"
    end
    
    # returns an reflection sql for a 
    # has and belongs to reflection
    #
    # the sql_conditions_sum are included
    def sql_by_has_and_belongs_to_many_reflection
      "#{quoted_parent_table_name}.#{parent_primary_key} " + \
        "IN (SELECT #{quoted_join_table}.#{primary_key_name} " + \
          "FROM #{join_table} #{quoted_join_table} WHERE #{quoted_join_table}.#{association_foreign_key} " + \
          "IN (SELECT #{quoted_table_name}.#{primary_key} FROM #{table_name} #{quoted_table_name} WHERE #{sql_conditions_sum}))"
    end
    
    # returns an reflection sql for a 
    # has many reflection
    #
    # the sql_conditions_sum are included
    #
    # returns the sql_by_has_many_through_reflection 
    # when the reflection is a through reflection
    #
    # returns the sql_by_has_many_normal_reflection 
    # when the reflection is not a through reflection
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
    
    # returns an reflection sql for a 
    # has many normal reflection
    #
    # the sql_conditions_sum are included
    #
    # sub method for sql_by_has_many_reflection
    def sql_by_has_many_normal_reflection
      "#{quoted_parent_table_name}.#{parent_primary_key} " + \
        "IN (SELECT #{quoted_table_name}.#{primary_key_name} " + \
          "FROM #{table_name} #{quoted_table_name} WHERE #{sql_conditions_sum})"
    end

    def sql_by_has_many_polymorphic_reflection
      self.cond_values << parent.klass.base_class.to_s
      
      "#{quoted_parent_table_name}.#{parent_primary_key} " + \
        "IN (SELECT #{quoted_table_name}.#{reflection.options[:as]}_id " + \
          "FROM #{table_name} #{quoted_table_name} WHERE " + \
            "#{quoted_table_name}.#{reflection.options[:as]}_type = ? AND " + \
            "#{sql_conditions_sum})"
    end
    
    # returns an reflection sql for a 
    # has many through reflection
    #
    # the sql_conditions_sum are included
    #
    # sub method for sql_by_has_many_reflection
    #
    # has many through is a has and belongs to many reflection
    # and this sql_string are returned
    def sql_by_has_many_through_has_many_reflection
      "#{quoted_parent_table_name}.#{parent_primary_key} " + \
        "IN (SELECT #{quoted_join_table}.#{primary_key_name} " + \
          "FROM #{join_table} #{quoted_join_table} WHERE #{quoted_join_table}.#{association_foreign_key} " + \
          "IN (SELECT #{quoted_table_name}.#{primary_key} FROM #{table_name} #{quoted_table_name} WHERE #{sql_conditions_sum}))"
    end

    def sql_by_has_many_through_belongs_to_reflection
      "#{quoted_parent_table_name}.#{primary_key_name} " + \
        "IN (SELECT #{quoted_join_table}.#{parent_primary_key} " + \
          "FROM #{join_table} #{quoted_join_table} WHERE #{quoted_join_table}.#{primary_key} " + \
          "IN (SELECT #{quoted_table_name}.#{primary_key_name} FROM #{table_name} #{quoted_table_name} WHERE #{sql_conditions_sum}))"
    end
    
    # returns an reflection sql for a 
    # has one reflection
    #
    # the sql_conditions_sum are included
    #
    # has one is a has many reflection
    # and this sql_string are returned
    def sql_by_has_one_reflection
      sql_by_has_many_reflection
    end
    
    # quotes the given table name
    # this is needed, because mysql overwrite table_name.column in subselects, too
    # example: "articles_1"
    def quote_table_name(unquoted_table_name, index=condition_index)
      index != start_index ? "#{unquoted_table_name}_#{index}" : unquoted_table_name
    end
    
    def child_condition_index_for_name(name, child_sql_join, block_id)
      "#{condition_name_prefix}_#{name}_#{child_sql_join}_#{block_id}"
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
