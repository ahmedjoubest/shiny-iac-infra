# Start with the Rocker Shiny image (includes R, Shiny, and Shiny Server)
FROM rocker/shiny:4.1.2

# Install system dependencies (if needed by paws or other R packages)
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev

# Install R packages required by the app
RUN R -e "install.packages('paws', dependencies = TRUE, repos = 'http://cran.rstudio.com/')"

# Copy the .Renviron file to the root directory
COPY .Renviron /srv/shiny-server/

# Create an R directory inside the container and copy aws_helpers.R to it
RUN mkdir -p /srv/shiny-server/R
COPY R/aws_helpers.R /srv/shiny-server/R/

# Copy the Shiny app to the Shiny Server's default directory
COPY app.R /srv/shiny-server/

# Expose the Shiny Server port (used by default)
EXPOSE 3838

# Start Shiny Server
CMD ["/usr/bin/shiny-server"]
