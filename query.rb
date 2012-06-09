require 'net/http'
require 'rubygems'
require 'tire'
require 'base64'
require 'fileutils'


s = Tire.search("articles") do
	query do
		# boolean do
		#  	should { string "Bitter"}
		#  	must_not { string "die"}
		# end
		string "Bitterfeld"
	end
end

puts s.to_curl

s.results.each do |document|
	puts document.fname
end	