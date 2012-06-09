# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard :shell do
  # watch %r{app/assets/javascripts/.*\.coffee$} do
  #   `bundle exec rake sprockets`
  # end

  # watch %r{(app/assets/javascripts/.*\.jst\.eco|app/assets/javascripts/.*\.coffee)$} do
  #   `bundle exec rake sprockets`
  # end


  watch %r{(app/assets/javascripts/.*\.jst\.eco|app/assets/javascripts/.*\.coffee)$} do
    puts "ok"
    `bundle exec rake sprockets`
  end

end


guard "jasmine-headless-webkit" do
  watch %r{spec/javascripts/.*\.coffee$}
  watch %r{app/assets/javascripts/.*\.coffee$}
  watch %r{app/assets/javascripts/.*\.jst\.eco$}
end
