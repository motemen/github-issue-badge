FROM ruby:2.0-onbuild
EXPOSE 3000
ENTRYPOINT ["bundle", "exec", "rackup", "-p", "3000"]
