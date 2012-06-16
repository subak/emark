# A sample Guardfile
# More info at https://github.com/guard/guard#readme

# guard :shell do
#   # watch %r{app/assets/javascripts/.*\.coffee$} do
#   #   `bundle exec rake sprockets`
#   # end

#   # watch %r{(app/assets/javascripts/.*\.jst\.eco|app/assets/javascripts/.*\.coffee)$} do
#   #   `bundle exec rake sprockets`
#   # end


#   watch %r{(app/assets/javascripts/.*\.jst\.eco|app/assets/javascripts/.*\.coffee)$} do
#     puts "ok"
#     `bundle exec rake sprockets`
#   end

# end

group :jasmine do
  guard "jasmine-headless-webkit" do
    #  watch %r{(spec/javascripts/.*\.coffee|app/assets/javascripts/.*\.coffee|app/assets/javascripts/.*\.jst\.eco)$}
    watch %r{spec/javascripts/.*\.coffee$}
    watch %r{app/assets/javascripts/.*\.coffee$}
    watch %r{app/assets/javascripts/.*\.jst\.eco$}
  end
end

group :rspec_publish_entry do
  guard :shell do
    watch %r{(spec/publish/entry_spec\.rb|app/workers/entry.rb)} do
      `rspec spec/publish/entry_spec.rb -cfs`
    end
  end
end
