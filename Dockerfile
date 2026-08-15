# Stage 1: Build the static site using Jekyll
FROM jekyll/builder:latest AS builder
WORKDIR /srv/jekyll

# Ensure proper permissions for the jekyll user
COPY --chown=jekyll:jekyll . .

# Install dependencies defined in Gemfile and build
RUN bundle install && bundle exec jekyll build

# Stage 2: Serve static files via Nginx
FROM nginx:alpine
COPY --from=builder /srv/jekyll/_site /usr/share/nginx/html

# Configure Nginx to listen on port 8080
RUN sed -i 's/listen\s*80;/listen 8080;/g' /etc/nginx/conf.d/default.conf

EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
