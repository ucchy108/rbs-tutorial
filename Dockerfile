FROM ruby:3.3.4-slim AS base

# Rails app lives here
WORKDIR /app

# Set production environment
ENV RAILS_ENV="development"


# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips pkg-config

# Copy application code
COPY . .

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ /usr/local/bundle/cache /usr/local/bundle/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# # Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

# Entrypoint prepares the database.
ENTRYPOINT ["/app/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
