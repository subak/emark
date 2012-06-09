# A sample Guardfile
# More info at https://github.com/guard/guard#readme

guard :shell do
  watch %r{app/.*\.rb} do
    puts "hoge"
  end

  watch %r{app/assets/javascripts/.*\.coffee$} do
    `bundle exec rake sprockets`
  end
end

guard "jasmine-headless-webkit" do
  watch %r{spec/javascripts/.*\.coffee$}
  watch %r{app/assets/javascripts/.*\.coffee$}
end
