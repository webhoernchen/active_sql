module ActiveSql::Finder

  # Generates a named condition scope for the model class.
  #
  # Static named scope
  # class Article
  #   active_sql_condition_scope :scope_name do |article|
  #     article.net_price.greater_than 100
  #   end
  # end
  #
  # => Article.scope_name.all
  #
  #
  # Dynamic named scope
  # class Article
  #   active_sql_condition_scope :scope_name do |article, min_price, max_price|
  #     article.net_price.greater_than min_price
  #     article.net_price.less_than max_price
  #   end
  # end
  #
  # => Article.scope_name(50, 100).all
  def active_sql_condition_scope(name, options={}, &block)
    active_sql_scope name, (lambda do |*args|
      conditions = generate_conditions_for_records(options) do |active_sql_condition|
        yield active_sql_condition, *args
      end
      hash_or_where conditions
    end)
  end

  # Generates a named order scope for the model class.
  #
  # Static named scope
  # class Article
  #   active_sql_order_scope :scope_name do |article|
  #     article.net_price
  #   end
  # end
  #
  # => Article.scope_name.all
  #
  # Dynamic named scope
  # class Article
  #   active_sql_order_scope :scope_name do |article, *args|
  #     article.net_price(*args)
  #   end
  # end
  #
  # => Article.scope_name(:sort => 'DESC').all
  def active_sql_order_scope(name, &block)
    active_sql_scope name, (lambda do |*args|
      order = generate_sort_condition do |active_sql_sort_condition|
        yield active_sql_sort_condition, *args
      end
      hash_or_order order
    end)
  end

  # Generates a condition scope for the model class on demand.
  #
  # class Article < ActiveRecord::Base
  # end
  #
  # scope = Article.by_active_sql_condition_scope do |article|
  #   article.net_price.greater_than_or_equal 50
  # end
  #
  # records = scope.all
  # or
  # records = scope.other_scope.all
  def by_active_sql_condition_scope(options= {}, &block)
    conditions = generate_conditions_for_records(options) do |active_sql_condition|
      yield active_sql_condition
    end
    where_or_scoped conditions
  end
  
  # Generates an order scope for the model class on demand.
  #
  # class Article < ActiveRecord::Base
  # end
  #
  # scope = Article.by_active_sql_order_scope do |article|
  #   article.net_price
  # end
  #
  # records = scope.all
  # or
  # records = scope.other_scope.all
  def by_active_sql_order_scope(&block)
    sort_condition = generate_sort_condition do |active_sql_sort_condition|
      yield active_sql_sort_condition
    end
    order_or_scoped sort_condition
  end
  
  # find a record
  # 
  # accept all options from the +find+ of ActiveRecord::Base of the second argument
  # like ":include, :sort"
  # the ":conditions" option is going to be overwrite
  # the first argument ":first" is set by default
  # 
  # the conditions in the block accept the same options 
  # like in docs of the ActiveSql::Condition
  # 
  # 
  # example: 
  # manufacturer = Manufacturer.find_by_active_sql do |manufacturer|
  #   manufacturer.name == 'Test'
  # end
  def find_by_active_sql(args={})
    args[:conditions] = generate_conditions_for_records(args) do |active_sql_condition|
      yield active_sql_condition
    end
    find(:first, args)
  end
  
  # find an array of records
  # 
  # accept all options from the +find+ of ActiveRecord::Base of the second argument
  # like ":include, :sort"
  # the ":conditions" option is going to be overwrite
  # the first argument ":all" is set by default
  # 
  # the conditions in the block accept the same options 
  # like in docs of the ActiveSql::Condition
  # 
  # 
  # example: 
  # manufacturers = Manufacturer.find_all_by_active_sql do |manufacturer|
  #   manufacturer.name == 'Test'
  # end
  def find_all_by_active_sql(args={})
    args[:conditions] = generate_conditions_for_records(args) do |active_sql_condition|
      yield active_sql_condition
    end
    find(:all, args)
  end

  # generate the find conditions for the find method of ActiveRecord::Base
  # 
  # accept all options from the +find+ of ActiveRecord::Base of the second argument
  # like ":include, :sort"
  # the ":conditions" option is going to be overwrite
  # the first argument ":all" is set by default
  # 
  # the conditions in the block accept the same options 
  # like in docs of the ActiveSql::Condition
  #
  # returns an array of a SQL-String and the values
  # 
  # example: ['manufacturer.name = ?', 'Test']
  def generate_conditions_for_records(args={}, &block)
    sql_join = args.delete(:sql_join)
    active_sql_condition = ActiveSql::Condition.new({:klass => self, :sql_join => sql_join})
    yield active_sql_condition
    cond = active_sql_condition.to_record_conditions
    
    if cond.size > 1
      cond
    else
      cond.first
    end
  end
  alias generate_conditions_for_record generate_conditions_for_records
  
  # generate an ActiveSql::SortCondition like in the docs of ActiveSql::SortCondition
  def generate_sort_condition(&block)
    condition = ActiveSql::SortCondition.new({:klass => self})
    sort_conditions = yield(condition)
    sort_conditions = [sort_conditions] unless sort_conditions.is_a?(Array)
    sort_condition = sort_conditions.collect(&:to_sort_condition).join(', ')
    
    # Fix for DEPRECATION WARNING in Rails 5.2: 
    # Dangerous query method (method whose arguments are used as raw SQL) called with non-attribute argument(s)
    if defined? Arel::Nodes::SqlLiteral
      Arel::Nodes::SqlLiteral.new sort_condition
    else
      sort_condition
    end
  end

  def active_sql_scope(name, *args, &block)
    if responds_to_scope?
      scope name, *args, &block
    else
      named_scope name, *args, &block
    end
  end

  def responds_to_scope?
    if @cached_responds_to_scope.nil?
      @cached_responds_to_scope = public_methods.collect(&:to_sym).include?(:scope)
    else
      @cached_responds_to_scope
    end
  end

  def where_or_scoped(conditions)
    if respond_to_where?
      where conditions
    else
      scoped :conditions => conditions
    end
  end

  def order_or_scoped(conditions)
    if respond_to_order?
      order conditions
    else
      scoped :order => conditions
    end
  end

  def respond_to_where?
    if @cached_respond_to_where.nil?
      @cached_respond_to_where = respond_to?(:where)
    else
      @cached_respond_to_where
    end
  end

  def respond_to_order?
    respond_to_where?
  end

  def hash_or_where(conditions)
    if rails_4?
      where conditions
    else
      {:conditions => conditions}
    end
  end

  def hash_or_order(conditions)
    if rails_4?
      order conditions
    else
      {:order => conditions}
    end
  end

  def rails_4?
    if @cached_rails_4.nil?
      @cached_rails_4 = Rails.version >= '4.0.0'
    else
      @cached_rails_4
    end
  end
end
