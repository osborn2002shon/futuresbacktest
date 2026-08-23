# syntax=docker/dockerfile:1

ARG RUBY_VERSION=4.0.6
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

ENV RAILS_ENV=development \
    RAILS_LOG_TO_STDOUT=1 \
    BUNDLE_PATH=/usr/local/bundle

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ /usr/local/bundle/ruby/*/cache

COPY . .
RUN chmod +x bin/* && \
    sed -i "s/\r$//g" bin/* && \
    sed -i "s/ruby\.exe$/ruby/" bin/*

FROM base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y ca-certificates && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

COPY --from=build --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails

USER rails

EXPOSE 3000

CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
