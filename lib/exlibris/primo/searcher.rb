# module Exlibris
#   module Primo
#     # == Overview
#     # Exlibris::Primo::Searcher searches Primo for records.
#     # Exlibris::Primo::Searcher must have sufficient metadata to make 
#     # the request. Sufficient means either:
#     #     * We have a Primo doc id
#     #     * We have either an isbn OR an issn
#     #     * We have a title AND an author AND a genre
#     # If none of these criteria are met, Exlibris::Primo::Searcher.search
#     # will not perform the search.
#     # Exlibris::Primo::Searcher will populate the following instance variables
#     # accessible through readers:
#     #   :count, :holdings, :rsrcs, :tocs, :related_links
#     # The reader :response makes the full xml result available as a Nokogiri::XML::Document.
#     class Searcher
#       #@required_setup = [ :base_url ]
#       #@setup_default_values = { :vid => "DEFAULT", :config => {} }
# 
#       attr_reader :response, :count
#       attr_reader :cover_image, :titles, :author
#       attr_reader :holdings, :rsrcs, :tocs, :related_links
#       PNX_NS = {'pnx' => 'http://www.exlibrisgroup.com/xsd/primo/primo_nm_bib'}
#       SEARCH_NS = {'search' => 'http://www.exlibrisgroup.com/xsd/jaguar/search'}
#     
#       # Instantiates the object and performs the search for based on the input search criteria.
#       # :setup parameter requires { :base_url => http://primo.institution.edu }
#       # Other optional parameters are :vid => "view_id", :config => { Hash of primo config settings}
#       # Hash of config settings are of the form:
#       #   {"libraries" => {"library_code1" => "library_display_1", "library_code2" => "library_display_1"}, "statuses" => {"status_code1" => "status_display_1", "status_code2" => "status_display_2"}}
#       # :search_params are a sufficient combination of 
#       #   { :primo_id => "primo_1", :isbn => "ISBN", :issn => "ISSN", :title => "Title", :author => "Author", :genre => "Genre" }
#       def initialize(setup, search_params)
#         @holdings = []
#         @rsrcs = []
#         @tocs = []
#         @related_links = []
#         @holding_attributes = Exlibris::Primo::Holding.base_attributes
#         @base_url = setup[:base_url]
#         raise_required_setup_parameter_error :base_url if @base_url.nil?
#         @institution = setup[:institution]
#         raise_required_setup_parameter_error :institution if @institution.nil?
#         @vid = setup.fetch(:vid, "DEFAULT")
#         raise_required_setup_parameter_error :vid if @vid.nil?
#         @config = setup.fetch(:config, {})
#         raise_required_setup_parameter_error :config if @config.nil?
#         search_params.each { |param, value| self.instance_variable_set("@#{param}".to_sym, value) }
#         # Perform the search
#         search
#       end
# 
#       private
#       def self.add_attr_reader(reader)
#         attr_reader reader.to_sym
#       end
#     
#       # Execute search based on instance vars
#       # Process Holdings based on display/availlibrary
#       # Process URLs based on links/linktorsrc
#       # Process TOCs based on links/linktotoc
#       def search
#         return if insufficient_query?
#         # Call Primo Web Services
#         unless @primo_id.nil? or @primo_id.empty?
#           get_record = Exlibris::Primo::WebService::GetRecord.new(@primo_id, @base_url, {:institution => @institution}) 
#           @response = get_record.response
#           process_record and process_search_results #since this is a search in addition to being a record call
#         else
#           brief_search = Exlibris::Primo::WebService::SearchBrief.new(search_params, @base_url, {:institution => @institution})
#           @response = brief_search.response
#           process_search_results
#         end
#       end
# 
#       # Determine whether we have sufficient search criteria to search
#       # Sufficient means either:
#       #     * We have a Primo doc id
#       #     * We have either an isbn OR an issn
#       #     * We have a title AND an author AND a genre
#       def insufficient_query?
#         return false unless (@primo_id.nil? or @primo_id.empty?)
#         return false unless (@issn.nil? or @issn.empty?) and (@isbn.nil? or @isbn.empty?)
#         return false unless (@title.nil? or @title.empty?) or (@author.nil? or @author.empty?) or (@genre.nil? or @genre.empty?)
#         return true
#       end
#     
#       # Search params are determined by input to Exlibris::PrimoWS::SearchBrief
#       def search_params
#         search_params = {}
#         unless (@issn.nil? or @issn.empty?) and (@isbn.nil? or @isbn.empty?)
#           search_params[:isbn] = @isbn unless @isbn.nil?
#           search_params[:issn] = @issn if search_params.empty?
#         else
#           search_params[:title] = @title unless @title.nil?
#           search_params[:author] = @author unless @title.nil? or @author.nil?
#           search_params[:genre] = @genre unless @title.nil? or @author.nil? or @genre.nil?
#         end
#         return search_params
#       end
#     
#       # Process a single record
#       def process_record
#         @count = response.at("//search:DOCSET", SEARCH_NS)["TOTALHITS"] unless response.nil? or @count
#         response.at("//pnx:addata", PNX_NS).children.each do |addata_child|
#           name = addata_child.name and value = addata_child.inner_text if addata_child.elem?
#           next if value.nil?
#           self.class.add_attr_reader name.to_sym unless name.nil?
#           instance_variable_set("@#{name}".to_sym, "#{value}") unless name.nil?
#         end
#         @cover_image = response.at("//pnx:addata/pnx:lad02", PNX_NS).inner_text unless response.at("//pnx:addata/pnx:lad02", PNX_NS).nil?
#         @titles = []
#         response.search("//pnx:display/pnx:title", PNX_NS).each do |title|
#           @titles.push(title.inner_text)
#         end
#         @authors = []
#         response.search("//pnx:display/pnx:creator", PNX_NS).each do |creator|
#           @authors.push(creator.inner_text)
#         end
#       end
#  
#       # Process search results
#       # Process Holdings based on display/availlibrary
#       # Process URLs based on links/linktorsrc
#       # Process TOCs based on links/linktotoc
#       def process_search_results
#         @count = response.at("//search:DOCSET", SEARCH_NS)["TOTALHITS"] unless response.nil? or @count
#         # Loop through records to set metadata for holdings, urls and tocs
#         response.search("//pnx:record", PNX_NS).each do |record|
#           # Default genre to article if necessary
#           record_genre = (record.xpath("pnx:addata/pnx:genre", PNX_NS).nil?) ? "article" : record.xpath("pnx:addata/pnx:genre", PNX_NS).inner_text
#           # Don't process if passed in genre doesn't match the record genre unless the discrepancy is only b/w journals and articles
#           # If we're working off id numbers, we should be good to proceed
#           next unless @primo_id or @isbn or @issn or 
#               @genre == record_genre or (@genre == "journal" and record_genre == "article")
#           # Just take the first element for record level elements 
#           # (should only be one, except sourceid which will be handled later)
#           record_id = record.xpath("pnx:control/pnx:recordid", PNX_NS).inner_text
#           record_title = record.xpath("pnx:display/pnx:title", PNX_NS).inner_text
#           record_author = record.xpath("pnx:display/pnx:creator", PNX_NS).inner_text
#           display_type = record.xpath("pnx:display/pnx:type", PNX_NS).inner_text
#           original_source_id = record.xpath("pnx:control/pnx:originalsourceid", PNX_NS).inner_text unless record.xpath("pnx:control/pnx:originalsourceid", PNX_NS).nil?
#           original_source_ids = process_control_hash(record, "pnx:control/pnx:originalsourceid", PNX_NS)
#           source_id = record.xpath("pnx:control/pnx:sourceid", PNX_NS).inner_text
#           source_ids = process_control_hash(record, "pnx:control/pnx:sourceid", PNX_NS)
#           source_record_id = record.xpath("pnx:control/pnx:sourcerecordid", PNX_NS).inner_text
#           # Process holdings
#           source_record_ids = process_control_hash(record, "pnx:control/pnx:sourcerecordid", PNX_NS)
#           record.xpath("pnx:display/pnx:availlibrary", PNX_NS).each do |availlibrary|
#             availlibrary, institution_code, library_code, id_one, id_two, status_code, origin = process_availlibrary availlibrary
#             holding_original_source_id = (origin.nil?) ? original_source_ids[record_id] : original_source_ids[origin] unless original_source_ids.empty?
#             holding_original_source_id = original_source_id if holding_original_source_id.nil?
#             holding_source_id = (origin.nil?) ? source_ids[record_id] : source_ids[origin] unless source_ids.empty?
#             holding_source_id = source_id if holding_source_id.nil?
#             holding_source_record_id = (origin.nil?) ? source_record_ids[record_id] : source_record_ids[origin] unless source_record_ids.empty?
#             holding_source_record_id =  source_record_id if holding_source_record_id.nil?
#             holding_parameters = {
#               :base_url => @base_url, :vid => @vid, :config => @config,
#               :record_id => record_id, :title => record_title, :author => record_author, 
#               :original_source_id => holding_original_source_id, :source_id => holding_source_id, 
#               :source_record_id => holding_source_record_id, :origin => origin, 
#               :availlibrary => availlibrary, :institution_code => institution_code, 
#               :library_code => library_code, :id_one => id_one, :id_two => id_two, 
#               :status_code => status_code, :origin => origin, :display_type => display_type, :notes => ""
#             }
#             holding = Exlibris::Primo::Holding.new(holding_parameters)
#             @holdings.push(holding) unless holding.nil?
#           end
#           # Process urls
#           record.xpath("pnx:links/pnx:linktorsrc", PNX_NS).each do |linktorsrc|
#             linktorsrc, v, url, display, institution_code, origin = process_linktorsrc linktorsrc
#             rsrc = Exlibris::Primo::Rsrc.new({
#               :record_id => record_id, :linktorsrc => linktorsrc, 
#               :v => v, :url => url, :display => display, 
#               :institution_code => institution_code, :origin => origin,
#               :notes => ""
#             }) unless linktorsrc.nil?
#             @rsrcs.push(rsrc) unless (rsrc.nil? or rsrc.url.nil?)
#           end
#           # Process tocs
#           record.xpath("pnx:links/pnx:linktotoc", PNX_NS).each do |linktotoc|
#             linktotoc, url, display = process_linktotoc linktotoc
#             toc = Exlibris::Primo::Toc.new({
#               :record_id => record_id, :linktotoc => linktotoc, 
#               :url => url, :display => display, 
#               :notes => ""
#             }) unless linktotoc.nil?
#             @tocs.push(toc) unless (toc.nil? or toc.url.nil?)
#           end
#           # Process addlinks
#           record.xpath("pnx:links/pnx:addlink", PNX_NS).each do |addlink|
#             addlink, url, display = process_addlink addlink
#             related_link = Exlibris::Primo::RelatedLink.new({
#               :record_id => record_id, :addlink => addlink, 
#               :url => url, :display => display, 
#               :notes => ""
#             }) unless addlink.nil?
#             @related_links.push(related_link) unless (related_link.nil? or related_link.url.nil?)
#           end
#         end
#       end
# 
#       def process_control_hash(record, xpath, ns)
#         h = {}
#         record.xpath(xpath, ns).each do |e|
#           str = e.inner_text unless e.nil?
#           a = str.split(/\$(?=\$)/) unless str.nil?
#           v = nil
#           o = nil
#           a.each do |s|
#             v = s.sub!(/^\$V/, "") unless s.match(/^\$V/).nil?
#             o = s.sub!(/^\$O/, "") unless s.match(/^\$O/).nil?
#           end
#           h[o] = v unless (o.nil? or v.nil?)
#         end
#         return h
#       end
#     
#       def process_availlibrary(input)
#         availlibrary, institution_code, library_code, id_one, id_two, status_code, origin =
#           nil, nil, nil, nil, nil, nil, nil
#         return institution_code, library_code, id_one, id_two, status_code, origin if input.nil? or input.inner_text.nil?
#         availlibrary = input.inner_text
#         availlibrary.split(/\$(?=\$)/).each do |s|
#           institution_code = s.sub!(/^\$I/, "") unless s.match(/^\$I/).nil?
#           library_code = s.sub!(/^\$L/, "") unless s.match(/^\$L/).nil?
#           id_one = s.sub!(/^\$1/, "") unless s.match(/^\$1/).nil?
#           id_two = s.sub!(/^\$2/, "") unless s.match(/^\$2/).nil?
#           # Always display "Check Availability" if this is from Primo.
#           #@status_code = s.sub!(/^\$S/, "") unless s.match(/^\$S/).nil?
#           status_code = "check_holdings"
#           origin = s.sub!(/^\$O/, "") unless s.match(/^\$O/).nil?
#         end
#         return availlibrary, institution_code, library_code, id_one, id_two, status_code, origin
#       end
#     
#       def process_linktorsrc(input)
#         linktorsrc, v, url, display, institution_code, origin = nil, nil, nil, nil, nil, nil
#         return linktorsrc, v, url, display, institution_code, origin if input.nil? or input.inner_text.nil?
#         linktorsrc = input.inner_text
#         linktorsrc.split(/\$(?=\$)/).each do |s|
#           v = s.sub!(/^\$V/, "")  unless s.match(/^\$V/).nil?
#           url = s.sub!(/^\$U/, "")  unless s.match(/^\$U/).nil?
#           display = s.sub!(/^\$D/, "")  unless s.match(/^\$D/).nil?
#           institution_code = s.sub!(/^\$I/, "") unless s.match(/^\$I/).nil?
#           origin = s.sub!(/^\$O/, "") unless s.match(/^\$O/).nil?
#         end
#         return linktorsrc, v, url, display, institution_code, origin
#       end
# 
#       def process_linktotoc(input)
#         linktotoc, url, display, = nil, nil, nil
#         return linktotoc, url, display if input.nil? or input.inner_text.nil?
#         linktotoc = input.inner_text
#         linktotoc.split(/\$(?=\$)/).each do |s|
#           url = s.sub!(/^\$U/, "")  unless s.match(/^\$U/).nil?
#           display = s.sub!(/^\$D/, "")  unless s.match(/^\$D/).nil?
#         end
#         return linktotoc, url, display
#       end
# 
#       def process_addlink(input)
#         addlink, url, display, = nil, nil, nil
#         return addlink, url, display if input.nil? or input.inner_text.nil?
#         addlink = input.inner_text
#         addlink.split(/\$(?=\$)/).each do |s|
#           url = s.sub!(/^\$U/, "")  unless s.match(/^\$U/).nil?
#           display = s.sub!(/^\$D/, "")  unless s.match(/^\$D/).nil?
#         end
#         return addlink, url, display
#       end
# 
#       def raise_required_setup_parameter_error(parameter)
#         raise "Initialization error in #{self.class}. Missing required setup parameter: #{parameter}."
#       end
#     end
#   end
# end