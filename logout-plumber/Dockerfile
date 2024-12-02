FROM rocker/r-ver:4.3.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev && rm -rf /var/lib/apt/lists/*

# Install required R packages
RUN R -e "install.packages(c('plumber', 'jsonlite'))"

# Set working directory and copy the R script
WORKDIR /app
COPY logout.R /app/logout.R

# Expose the port the application runs on
EXPOSE 6030

# Command to run the R script
CMD ["Rscript", "logout.R"]
