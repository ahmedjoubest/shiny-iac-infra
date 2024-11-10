# Start with the Rocker Shiny image (includes R, Shiny, and Shiny Server)
FROM rocker/shiny:4.1.2

# Copy the Shiny app to the Shiny Server's default directory
COPY app.R /srv/shiny-server/

# Expose the Shiny Server port (used by default)
EXPOSE 3838

# Start Shiny Server
CMD ["/usr/bin/shiny-server"]