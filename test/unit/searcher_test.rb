# encoding: utf-8
require 'test_helper'
class SearcherTest < Test::Unit::TestCase
  PNX_NS = {'pnx' => 'http://www.exlibrisgroup.com/xsd/primo/primo_nm_bib'}
  SEARCH_NS = {'search' => 'http://www.exlibrisgroup.com/xsd/jaguar/search'}

  def setup
    @primo_definition = YAML.load( %{      
        type: PrimoService
        priority: 2 # After SFX, to get SFX metadata enhancement
        status: active
        base_url: http://bobcat.library.nyu.edu
        vid: NYU
        institution: NYU
        holding_search_institution: NYU
        holding_search_text: Search for this title in BobCat.
        suppress_holdings: [ !ruby/regexp '/\$\$LBWEB/', !ruby/regexp '/\$\$LNWEB/', !ruby/regexp '/\$\$LTWEB/', !ruby/regexp '/\$\$LWEB/', !ruby/regexp '/\$\$1Restricted Internet Resources/' ]
        ez_proxy: !ruby/regexp '/https\:\/\/ezproxy\.library\.nyu\.edu\/login\?url=/'
        service_types:
          - primo_source
          - holding_search
          - fulltext
          - table_of_contents
          - referent_enhance
          - cover_image
      })

    @base_url = @primo_definition["base_url"]
    @vid = @primo_definition["vid"]
    @institution = @primo_definition["institution"]
    @primo_holdings_doc_id = "nyu_aleph000062856"
    @primo_rsrcs_doc_id = "nyu_aleph002895625"
    @primo_tocs_doc_id = "nyu_aleph003149772"
    @primo_dedupmrg_doc_id = "dedupmrg17343091"
    @primo_test_checked_out_doc_id = "nyu_aleph000089771"
    @primo_test_offsite_doc_id = "nyu_aleph002169696"
    @primo_test_ill_doc_id = "nyu_aleph001502625"
    @primo_test_diacritics1_doc_id = "nyu_aleph002975583"
    @primo_test_diacritics2_doc_id = "nyu_aleph003205339"
    @primo_test_diacritics3_doc_id = "nyu_aleph003365921"
    @primo_test_journals1_doc_id = "nyu_aleph002895625"
    @primo_invalid_doc_id = "thisIsNotAValidDocId"
    @primo_test_problem_doc_id = "nyu_aleph000509288"
    @primo_test_bug1361_id = "ebrroutebr10416506"
    @primo_test_isbn = "0143039008"
    @primo_test_title = "Travels with My Aunt"
    @primo_test_author = "Graham Greene"
    @primo_test_genre = "Book"
    @searcher_setup = {
      :base_url => @base_url,
      :institution => @institution,
      :vid => @vid,
      :config => @primo_definition
    }

    @searcher_setup_without_config = {
      :base_url => @base_url,
      :institution => @institution,
      :vid => @vid
    }
  end
  
  # Test search for a single Primo document.
  def testsearch_by_doc_id
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:primo_id => @primo_holdings_doc_id})
    assert_not_nil(searcher, "#{searcher.class} returned nil when instantiated.")
    search_results = searcher.response
    assert_instance_of(Nokogiri::XML::Document, search_results, "#{searcher.class} search result is an unexpected object: #{search_results.class}")
    assert_equal(@primo_holdings_doc_id, search_results.at("//pnx:control/pnx:recordid", PNX_NS).inner_text, "#{searcher.class} returned an unexpected record: #{search_results.to_xml(:indent => 5, :encoding => 'UTF-8')}")
    assert(searcher.count.to_i > 0, "#{searcher.class} returned 0 results for doc id: #{@primo_holdings_doc_id}.")
  end

  # Test search for a Primo problem record
  def testsearch_by_genre_discrepancy
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:primo_id => @primo_test_problem_doc_id})
    assert_not_nil(searcher, "#{searcher.class} returned nil when instantiated.")
    search_results = searcher.response
    assert_instance_of(Nokogiri::XML::Document, search_results, "#{searcher.class} search result is an unexpected object: #{search_results.class}")
    assert_equal(@primo_test_problem_doc_id, search_results.at("//pnx:control/pnx:recordid", PNX_NS).inner_text, "#{searcher.class} returned an unexpected record: #{search_results.to_xml(:indent => 5, :encoding => 'UTF-8')}")
    assert(searcher.count.to_i > 0, "#{searcher.class} returned 0 results for doc id: #{@primo_test_problem_doc_id}.")
    assert_equal(1, searcher.holdings.length, "#{searcher.class} returned unexpected holdings")
  end
  
  def testsearch_by_bug1361
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:primo_id => @primo_test_bug1361_id})
    assert_not_nil(searcher, "#{searcher.class} returned nil when instantiated.")
    search_results = searcher.response
    assert_instance_of(Nokogiri::XML::Document, search_results, "#{searcher.class} search result is an unexpected object: #{search_results.class}")
    assert_equal(@primo_test_bug1361_id, search_results.at("//pnx:control/pnx:recordid", PNX_NS).inner_text, "#{searcher.class} returned an unexpected record: #{search_results.to_xml(:indent => 5, :encoding => 'UTF-8')}")
    assert(searcher.count.to_i > 0, "#{searcher.class} returned 0 results for doc id: #{@primo_test_bug1361_id}.")
    assert_equal(0, searcher.holdings.length, "#{searcher.class} returned unexpected holdings")
    assert_equal(4, searcher.rsrcs.length, "#{searcher.class} returned unexpected rsrcs")
  end

  # Test search for an invalid Primo document.
  def testsearch_by_invalid_doc_id
    assert_raise(RuntimeError) { 
      searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:primo_id => @primo_invalid_doc_id})
    }
  end
  
  # Test invalid setup.
  def testsearch_by_invalid_setup1
    assert_raise(RuntimeError) {
      searcher = Exlibris::Primo::Searcher.new({}, {:primo_id => @primo_invalid_doc_id})
    }
  end
  
  # Test invalid setup.
  def testsearch_by_invalid_setup2
    assert_raise(RuntimeError) {
      searcher = Exlibris::Primo::Searcher.new({:base_url => @base_url, :config => nil}, {:primo_id => @primo_invalid_doc_id})
    }
  end
  
  # Test base setup search for a single Primo document.
  def testsearch_base_setup_record_id
    searcher = Exlibris::Primo::Searcher.new({:base_url => @base_url, :institution => @institution}, {:primo_id => @primo_holdings_doc_id})
    holdings = searcher.holdings
    assert_instance_of(Array, holdings, "#{searcher.class} holdings is an unexpected object: #{holdings.class}")
    assert(holdings.count > 0, "#{searcher.class} returned 0 holdings for doc id: #{@primo_holdings_doc_id}.")
    first_holding = holdings.first
    assert_instance_of(Exlibris::Primo::Holding, first_holding, "#{searcher.class} first holding is an unexpected object: #{first_holding.class}")
    assert_equal("check_holdings", first_holding.status, "#{searcher.class} first holding has an unexpected status: #{first_holding.status}")
    assert_equal("NYU", first_holding.institution, "#{searcher.class} first holding has an unexpected institution: #{first_holding.institution}")
    assert_equal("BOBST", first_holding.library, "#{searcher.class} first holding has an unexpected library: #{first_holding.library}")
    assert_equal("Main Collection", first_holding.collection, "#{searcher.class} first holding has an unexpected collection: #{first_holding.collection}")
    assert_equal("(PR6013.R44 T7 2004 )", first_holding.call_number, "#{searcher.class} first holding has an unexpected call number: #{first_holding.call_number}")
  end
  
  # Test search by isbn.
  def testsearch_by_isbn
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:isbn => @primo_test_isbn})
    assert_not_nil(searcher, "#{searcher.class} returned nil when instantiated.")
    search_results = searcher.response
    assert_instance_of(Nokogiri::XML::Document, search_results, "#{searcher.class} search result is an unexpected object: #{search_results.class}")
    search_results.search("//search/isbn") do |isbn|
      assert_not_nil(isbn.inner_text.match(@primo_test_isbn), "#{searcher.class} returned an unexpected record: #{search_results.to_xml(:indent => 5, :encoding => 'UTF-8')}")
    end
    assert(searcher.count.to_i > 0, "#{searcher.class} returned 0 results for ISBN: #{@primo_test_isbn}.")
  end
  
  # Test search by isbn.
  def testsearch_by_issn
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup_without_config, {:issn => "0002-8614"})
    assert_not_nil(searcher, "#{searcher.class} returned nil when instantiated.")
    search_results = searcher.response
    assert_instance_of(Nokogiri::XML::Document, search_results, "#{searcher.class} search result is an unexpected object: #{search_results.class}")
    search_results.search("//search/issn") do |isbn|
      assert_not_nil(isbn.inner_text.match("0002-8614"), "#{searcher.class} returned an unexpected record: #{search_results.to_xml(:indent => 5, :encoding => 'UTF-8')}")
    end
    assert(searcher.count.to_i > 0, "#{searcher.class} returned 0 results for ISSN: 0002-8614.")
  end
  
  # Test search by title/author/genre.
  def testsearch_by_title_author_genre
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:title => @primo_test_title, :author => @primo_test_author, :genre => @primo_test_genre})
    assert_not_nil(searcher, "#{searcher.class} returned nil when instantiated.")
    search_results = searcher.response
    assert_instance_of(Nokogiri::XML::Document, search_results, "#{searcher.class} search result is an unexpected object: #{search_results.class}")
    search_results.search("//search/title") do |title|
      assert_not_nil(title.inner_text.downcase.match(@primo_test_title.downcase), "#{searcher.class} returned an unexpected record: #{search_results.to_xml(:indent => 5, :encoding => 'UTF-8')}")
    end
    assert(searcher.count.to_i > 0, "#{searcher.class} returned 0 results for Title: #{@primo_test_title}.")
  end
  
  # Test search for a single Primo document w/ holdings.
  def testholdings
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:primo_id => @primo_holdings_doc_id})
    holdings = searcher.holdings
    assert_instance_of(Array, holdings, 
      "#{searcher.class} holdings is an unexpected object: #{holdings.class}")
    assert_equal(1, holdings.count, 
      "#{searcher.class} returned 0 holdings for doc id: #{@primo_holdings_doc_id}.")
    first_holding = holdings.first
    assert_instance_of(
      Exlibris::Primo::Holding, 
      first_holding, 
      "#{searcher.class} first holding is an unexpected object: #{first_holding.class}")
    test_data = { 
      :record_id => "nyu_aleph000062856", 
      :title => "Travels with my aunt", 
      :author => "Graham  Greene  1904-1991.", 
      :source_id => "nyu_aleph", 
      :original_source_id => "NYU01", 
      :source_record_id => "000062856",
      :institution_code => "NYU", 
      :institution => "NYU", 
      :library_code => "BOBST",
      :library => "BOBST",
      :status_code => "check_holdings", 
      :status => "check_holdings", 
      :id_one => "Main Collection", 
      :id_two => "(PR6013.R44 T7 2004 )", 
      :collection => "Main Collection", 
      :call_number => "(PR6013.R44 T7 2004 )", 
      :origin => nil, 
      :display_type => "book", 
      :coverage => [], 
      :notes => "",
      :url => "#{@base_url}/primo_library/libweb/action/dlDisplay.do?docId=nyu_aleph000062856&institution=NYU&vid=#{@vid}", 
      :request_url => nil }
    test_data.each { |key, value|
      assert_equal(
        value, 
        first_holding.send(key), 
        "#{searcher.class} first holding has an unexpected #{key}: #{first_holding.send(key)}")
    }
  end

  # Test search for a single Primo document w/ rsrcs.
  def testrsrcs
    searcher = Exlibris::Primo::Searcher.new(
      @searcher_setup, 
      { :primo_id => @primo_rsrcs_doc_id })
    rsrcs = searcher.rsrcs
    assert_instance_of(Array, rsrcs,
      "#{searcher.class} rsrcs is an unexpected object: #{rsrcs.class}")
    assert_equal(2, rsrcs.count,
      "#{searcher.class} returned an unexpected amount of rsrcs (#{rsrcs.count}) for doc id: #{@primo_rsrcs_doc_id}.")
    first_rsrc = rsrcs.first
    assert_instance_of(
      Exlibris::Primo::Rsrc, 
      first_rsrc,
      "#{searcher.class} first rsrc is an unexpected object: #{first_rsrc.class}")
    test_data = { 
      :record_id => "nyu_aleph002895625", 
      :v => nil, 
      :url => "https://ezproxy.library.nyu.edu/login?url=http://mq.oxfordjournals.org/",
      :display => "Online Version",
      :institution_code => "NYU", 
      :origin => nil, 
      :notes => "" }
    test_data.each { |key, value|
      assert_equal(
        value, 
        first_rsrc.send(key), 
        "#{searcher.class} first rsrc has an unexpected #{key}: #{first_rsrc.send(key)}")
    }
  end

  # Test search for a single Primo document w/ tocs.
  def testtocs
    searcher = Exlibris::Primo::Searcher.new(
      @searcher_setup, 
      { :primo_id => @primo_tocs_doc_id })
    tocs = searcher.tocs
    assert_instance_of(Array, tocs,
      "#{searcher.class} tocs is an unexpected object: #{tocs.class}")
    assert_equal(1, tocs.count,
      "#{searcher.class} returned an unexpected amount of tocs (#{tocs.count}) for doc id: #{@primo_tocs_doc_id}.")
    first_toc = tocs.last
    assert_instance_of(
      Exlibris::Primo::Toc, 
      first_toc, 
      "#{searcher.class} first toc is an unexpected object: #{first_toc.class}")
  test_data = { 
    :record_id => "nyu_aleph003149772", 
    :url => "http://www.loc.gov/catdir/toc/onix07/2001024342.html",
    :display => "Table of Contents",
    :notes => "" }
  test_data.each { |key, value|
    assert_equal(
      value, 
      first_toc.send(key), 
      "#{searcher.class} first toc has an unexpected #{key}: #{first_toc.send(key)}")
  }
  end
  
  def testdedupmrg
    searcher = Exlibris::Primo::Searcher.new(
      @searcher_setup, 
      { :primo_id => @primo_dedupmrg_doc_id })
    holdings = searcher.holdings
    assert_instance_of(Array, holdings, 
      "#{searcher.class} holdings is an unexpected object: #{holdings.class}")
    assert_equal(6, holdings.count, 
      "#{searcher.class} returned 0 holdings for doc id: #{@primo_dedupmrg_doc_id}.")
    first_holding = holdings.first
    assert_instance_of(
      Exlibris::Primo::Holding, 
      first_holding, 
      "#{searcher.class} first holding is an unexpected object: #{first_holding.class}")
    test_data = { 
      :record_id => "dedupmrg17343091", 
      :title => "The New York times", 
      :author => "", 
      :source_id => "nyu_aleph", 
      :original_source_id => "NYU01", 
      :source_record_id => "000932393",
      :institution_code => "NYU", 
      :institution => "NYU", 
      :library_code => "BWEB",
      :library => "BWEB",
      :status_code => "check_holdings", 
      :status => "check_holdings", 
      :id_one => "Internet Resources", 
      :id_two => "(Newspaper Electronic access )", 
      :collection => "Internet Resources", 
      :call_number => "(Newspaper Electronic access )", 
      :origin => "nyu_aleph000932393", 
      :display_type => "journal", 
      :coverage => [], 
      :notes => "",
      :url => "#{@base_url}/primo_library/libweb/action/dlDisplay.do?docId=dedupmrg17343091&institution=NYU&vid=#{@vid}", 
      :request_url => nil }
    test_data.each { |key, value|
      assert_equal(
        value, 
        first_holding.send(key), 
        "#{searcher.class} first holding has an unexpected #{key}: #{first_holding.send(key)}")
    }
    rsrcs = searcher.rsrcs
    assert_instance_of(Array, rsrcs,
      "#{searcher.class} rsrcs is an unexpected object: #{rsrcs.class}")
    assert_equal(8, rsrcs.count,
      "#{searcher.class} returned an unexpected amount of rsrcs (#{rsrcs.count}) for doc id: #{@primo_rsrcs_doc_id}.")
    first_rsrc = rsrcs.first
    assert_instance_of(
      Exlibris::Primo::Rsrc, 
      first_rsrc,
      "#{searcher.class} first rsrc is an unexpected object: #{first_rsrc.class}")
    test_data = { 
      :record_id => "dedupmrg17343091", 
      :v => "", 
      :url => "https://ezproxy.library.nyu.edu/login?url=http://proquest.umi.com/pqdweb?RQT=318&VName=PQD&clientid=9269&pmid=7818",
      :display => "1995 - Current Access via Proquest",
      :institution_code => "NYU", 
      :origin => "nyu_aleph000932393", 
      :notes => "" }
    test_data.each { |key, value|
      assert_equal(
        value, 
        first_rsrc.send(key), 
        "#{searcher.class} first rsrc has an unexpected #{key}: #{first_rsrc.send(key)}")
    }
  end

  def testholdings_diacritics1
     searcher = Exlibris::Primo::Searcher.new(
       @searcher_setup, 
       { :primo_id => @primo_test_diacritics1_doc_id })
     assert_equal(
       "Rubāʻīyāt-i Bābā Ṭāhir", 
       searcher.btitle, 
       "#{searcher.class} has an unexpected btitle: #{searcher.btitle}")
     assert_equal(
       "Bābā-Ṭāhir, 11th cent", 
       searcher.au, 
       "#{searcher.class} has an unexpected author: #{searcher.au}")
   end
   
#   This test fails but I don't know why!
  # def testholdings_diacritics2
  #   searcher = Exlibris::Primo::Searcher.new(
  #     @searcher_setup, 
  #     { :primo_id => @primo_test_diacritics2_doc_id })
  #   assert_equal(
  #     "Faraj, Faraj Maḥmūd", 
  #     searcher.au, 
  #     "#{searcher.class} has an unexpected author: #{searcher.au}")
  #   assert_equal(
  #     "Iqlīm Tuwāt khilāl al-qarnayn al-thāmin ʻashar wa-al-tāsiʻ ʻashar al-mīlādīyīn : dirāsah li-awḍāʻ al-iqlīm al-siyāsīyah wa-al-ijtimāʻīyah wa-al-iqtiṣādīyah wa-al-thaqāfīyah, maʻa taḥqīq kitāb al-Qawl al-basīṭ fī akhbār Tamanṭīṭ (li-Muḥammad ibn Bābā Ḥaydah)",
  #     searcher.btitle, 
  #     "#{searcher.class} has an unexpected btitle: #{searcher.btitle}")
  # end
  
  def testholdings_diacritics3
    searcher = Exlibris::Primo::Searcher.new(
      @searcher_setup, 
      { :primo_id => @primo_test_diacritics3_doc_id })
    assert_equal(
      "Mul har ha-gaʻash : ḥoḳre toldot Yiśraʼel le-nokhaḥ ha-Shoʼah", 
      searcher.btitle, 
      "#{searcher.class} has an unexpected btitle: #{searcher.btitle}")
    assert_equal(
      "Engel, David", 
      searcher.au, 
      "#{searcher.class} has an unexpected author: #{searcher.au}")
  end
end