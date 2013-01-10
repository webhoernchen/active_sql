module ShouldaMacros

  def should_not_raise_an_error
    should "not raise an error" do 
      assert_nothing_raised { subject }
    end
  end

  def should_match_sql_condition_part(expected_sql_part, affix='')
    should "match sql condition part #{affix}" do
      assert_match Regexp.new(expected_sql_part), @sql_condition.first,
        "Could not find '#{expected_sql_part}' in @sql_condition"
    end
  end

  def should_match_complete_sql(expected_sql)
    should_match_sql_condition_part expected_sql, 'complete'
  end

  def should_match_sql_condition_parts(expected_sql_parts)
    expected_sql_parts.each_with_index do |expected_sql_part, index|
      should_match_sql_condition_part(expected_sql_part.gsub(/_\\[0-9]/, "_([0-9]*)"), index)
    end
  end

  def should_set_follow_sql_values(*expected_values)
    should "set follow sql values" do
      assert_equal expected_values.flatten, @sql_condition[1..-1]
    end
  end

  def should_create_a_valid_sql_condition_for_klass(klass)
    should "not raise an error" do
      assert_nothing_raised(ActiveRecord::PreparedStatementInvalid) do
        assert_nothing_raised(ActiveRecord::StatementInvalid) do
          klass.find(:all, :conditions => @sql_condition)
        end
      end
    end
  end
end
