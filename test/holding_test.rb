require 'test_helper'
class HoldingTest < Test::Unit::TestCase
  def setup
    @record_id = "aleph002895625"
  end

  def test_new_holding
    assert_nothing_raised {
      holding = Exlibris::Primo::Holding.new :record_id => @record_id,
        :original_id => @record_id, :title => "Holding Title", :author => "Holding Author", 
        :display_type => "Book"
      assert_equal "aleph002895625", holding.record_id
      assert_equal "aleph002895625", holding.original_id
      assert_equal "Holding Title", holding.title
      assert_equal "Holding Author", holding.author
      assert_equal "Book", holding.display_type
    }
  end
end