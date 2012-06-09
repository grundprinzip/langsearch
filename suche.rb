require 'net/http'
require 'rubygems'
require 'tire'
require 'base64'
require 'fileutils'
require 'net/http/post/multipart'
# require 'rest_client'

BASE = "http://www.archiefleeuwardercourant.nl"

def search(incl, not_incl="", page=0)

	base_uri = URI("http://www.archiefleeuwardercourant.nl/srch/query.do")

	form_data = {
		:q => incl,
		:qOr => not_incl,
		:qNot => "",
		:qpubcode => "LC", # Check again
		:alt => "on",
		:qSI => 20060101,
		:startDate => "29-07-1752",
		:endDate => "10-05-2012",
		:qSD => "29", # Start Date
		:qSM => "7", # Start Month
		:qSY => "1752", # Star Year
		:qED => "10", # End Date
		:qEM => "5", # End Month
		:qEY => "2012", # End Year
		:x => 27,
		:y => 24,
		:from => page
	}

	res = Net::HTTP.post_form(base_uri, form_data)
end	


def find_articles(body, incl, not_incl)

	articles = []
	pdfs = []
	body.scan(/showArticleVw\('(.*?)', 'pdf'\)/) { |match| 
		articles << "/vw/article.do?id=" + match[0] + "&vw=pdf" + "&lm=#{incl}%2C#{not_incl}%2CLC"
		pdfs << "http://www.archiefleeuwardercourant.nl/vw/pdf.do?id=" + match[0]
	}

	# PDFs contains the link to all pdfs for each article one
	pdfs
end

# Download a file identified by the file URI and extract the id for latter 
# reference
def download(file)
	uri = URI.parse(file)
	id=uri.query.match(/id=(.*)/)[1]

	Net::HTTP.start(uri.host) do |http|
	    resp = http.get(uri.path + "?" + uri.query)
	    open("docs/#{id}.pdf", "wb") do |file|
	        file.write(resp.body)
		end
	end
	id
end

# Find all pdfs
FileUtils.rmtree("docs")
Dir.mkdir("docs")

# Store all documents
all_documents = []
stop = false
page = 0
while !stop
	res = search("bitterfeld","", page)
	current = find_articles(res.body, "bitterfeld", "")
	all_documents += current
	page += current.size

	if current.size == 0
		stop = true
	end

	stop = true
end

puts "Starting download"
i = 1
document_names = []
all_documents.each do |pdf|
	puts "Downloading #{i}/#{all_documents.size}"
	document_names << download(pdf)
	i += 1
end

puts "Starting indexing"

# Create and setup the indexer
Tire.index "articles" do
	delete
	create :mappings => {
		:article => {
			:properties => {
				:name => {
					:type => "string"
				},
				:file => {
					:type => "attachment",
					:fields => {
						:title => {:store => "yes"},
						:file => { 
							:term_vector => "with_positions_offsets",
							:store => "yes"
						}
					}
				 },
				:date => {:type => "string"}
			}
		}
	}

	#Import all files
	i = 1
	document_names.each do |pdf|
		puts "Uploading #{i}"

		data = "{\"file\":\"#{Base64.strict_encode64(File.read("docs/#{pdf}.pdf"))}\", \"fname\":\"#{pdf}\", \"fdate\":\"#{pdf[3..6]}-#{pdf[7..8]}-#{pdf[9..10]}\"}"
		url = URI("http://localhost:9200/articles/article")

		post = Net::HTTP::Post.new(url.path)
		post.body = data

		res = Net::HTTP.start(url.host, url.port) do |http|
			http.request(post)
		end

		puts res




		# File.open("docs/#{pdf}.pdf") do |f|
		# 	req = Net::HTTP::Post::Multipart.new( url.path,
		#     	"file" => UploadIO.new(f, "application/pdf", "#{pdf}.pdf"),
		#     	"name" => pdf,
		#     	"date" => "#{pdf[3..6]}-#{pdf[7..8]}-#{pdf[9..10]}")
		#     res = Net::HTTP.start(url.host, url.port) do |http|
		#         http.request(req)
		#       end
		# end


		# result = RestClient.post("http://localhost:9200/articles/article",
		# {
		# 	:file=> File.new("docs/#{pdf}.pdf"),
		# 	:name => pdf,
		# 	:date => "#{pdf[3..6]}-#{pdf[7..8]}-#{pdf[9..10]}"
		# }.to_json, :content_type => :json
		# 	)

		# puts result.code	
		i += 1
	end

end	



