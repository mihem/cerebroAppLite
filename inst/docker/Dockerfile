FROM rocker/shiny:4.5.2

# Install system libraries
# These are common dependencies for R packages (especially for spatial/genomics packages)
RUN apt-get update --yes \
  && apt-get upgrade --yes \
  && apt-get install --yes \
  libhdf5-dev \
  cmake \
  pkg-config \
  libnlopt-dev \
  build-essential \
  gfortran \
  libcurl4-openssl-dev \
  libssl-dev \
  libxml2-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libfreetype6-dev \
  libpng-dev \
  libglib2.0-dev \
  libjpeg-dev \
  libtiff-dev \
  libcairo2-dev \
  libsqlite3-dev \
  libgit2-dev \
  libssh2-1-dev \
  libmagick++-dev \
  libgsl-dev \
  libglpk-dev \
  && rm -rf /var/lib/apt/lists/*

# Clean up default shiny server examples
RUN rm -rf /srv/shiny-server/*

# Install R packages required by the app
# Using Posit Package Manager for faster installation of binaries
# 1. Install BiocManager and Bioconductor packages
RUN R -e 'install.packages("BiocManager", repos = "https://packagemanager.posit.co/cran/__linux__/noble/2025-04-09"); \
          BiocManager::install(c("SingleR", "monocle", "DelayedArray", "HDF5Array"))'

# 2. Install electricShine (from GitHub, if needed)
RUN R -e 'install.packages("remotes", repos = "https://packagemanager.posit.co/cran/__linux__/noble/2025-04-09"); \
          tryCatch(remotes::install_github("chasemc/electricShine"), error = function(e) warning("electricShine install failed"))'

# 3. Install CRAN packages
RUN R -e 'install.packages(c(\
    "qs", \
    "shiny", \
    "shinydashboard", \
    "shinymanager", \
    "shinyWidgets", \
    "shinyjs", \
    "dplyr", \
    "DT", \
    "plotly", \
    "digest", \
    "shinyFiles", \
    "glue", \
    "shinycssloaders", \
    "readr", \
    "tidyselect", \
    "Seurat", \
    "SingleR", \
    "monocle", \
    "openxlsx", \
    "patchwork", \
    "tidyverse", \
    "DelayedArray", \
    "plotly", \
    "ggplot2", \
    "electricShine", \
    "htmlwidgets", \
    "devtools", \
    "HDF5Array" \
  ), \
  repos = "https://packagemanager.posit.co/cran/__linux__/noble/2025-04-09")'

# Copy custom shiny-server configuration for WebGL support
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

# Copy the app files to the shiny-server directory
WORKDIR /srv/shiny-server/
COPY . .

# Fix permissions for logs
RUN mkdir -p /etc/cont-init.d \
    && echo '#!/usr/bin/with-contenv bash\nmkdir -p /var/log/shiny-server\nchmod 777 /var/log/shiny-server' > /etc/cont-init.d/02_fix_log_perms \
    && chmod +x /etc/cont-init.d/02_fix_log_perms

RUN mkdir -p /etc/services.d/shiny-server \
    && echo '#!/usr/bin/with-contenv bash\numask 000\nexec /usr/bin/shiny-server 2>&1' > /etc/services.d/shiny-server/run \
    && chmod +x /etc/services.d/shiny-server/run

# Expose port 3838 (default for shiny-server)
EXPOSE 3838

# CMD is inherited from rocker/shiny (starts shiny-server)
