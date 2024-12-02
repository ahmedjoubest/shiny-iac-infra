# Start with the Rocker Shiny image (includes R, Shiny, and Shiny Server)
FROM rocker/shiny:4.1.2

# Install system dependencies (if needed by paws or other R packages)
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev

# Install R packages required by the app
RUN R -e "install.packages(c('paws', 'shinyjs', 'sass'), dependencies = TRUE, repos = 'http://cran.rstudio.com/')"

# Copy the .Renviron file to the root directory
COPY .Renviron /srv/shiny-server/

# Copy the entire R directory into the container
COPY R/ /srv/shiny-server/R/

# Copy the entire www directory into the container
COPY www/ /srv/shiny-server/www/

# Copy the Shiny app to the Shiny Server's default directory
COPY app.R /srv/shiny-server/

# Set ownership of the www directory to the shiny user (for sass package - autosaving SCSS)
RUN chown -R shiny:shiny /srv/shiny-server/www

# Expose the Shiny Server port (used by default)
EXPOSE 3838

# Start Shiny Server
CMD ["/usr/bin/shiny-server"]
