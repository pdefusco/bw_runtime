# ###########################################################################
#
#  CLOUDERA COMMUNITY RUNTIMES
#
# (C) Cloudera, Inc. 2022
#  All rights reserved.
#
#  Applicable Open Source License: Apache 2.0
#
#  NOTE: Cloudera open source products are modular software products
#  made up of hundreds of individual components, each of which was
#  individually copyrighted.  Each Cloudera open source product is a
#  collective work under U.S. Copyright Law. Your license to use the
#  collective work is as provided in your written agreement with
#  Cloudera.  Used apart from the collective work, this file is
#  licensed for your use pursuant to the open source license
#  identified above.
#
#  This code is provided to you pursuant a written agreement with
#  (i) Cloudera, Inc. or (ii) a third-party authorized to distribute
#  this code. If you do not have a written agreement with Cloudera nor
#  with an authorized and properly licensed third party, you do not
#  have any rights to access nor to use this code.
#
#  Absent a written agreement with Cloudera, Inc. (“Cloudera”) to the
#  contrary, A) CLOUDERA PROVIDES THIS CODE TO YOU WITHOUT WARRANTIES OF ANY
#  KIND; (B) CLOUDERA DISCLAIMS ANY AND ALL EXPRESS AND IMPLIED
#  WARRANTIES WITH RESPECT TO THIS CODE, INCLUDING BUT NOT LIMITED TO
#  IMPLIED WARRANTIES OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY AND
#  FITNESS FOR A PARTICULAR PURPOSE; (C) CLOUDERA IS NOT LIABLE TO YOU,
#  AND WILL NOT DEFEND, INDEMNIFY, NOR HOLD YOU HARMLESS FOR ANY CLAIMS
#  ARISING FROM OR RELATED TO THE CODE; AND (D)WITH RESPECT TO YOUR EXERCISE
#  OF ANY RIGHTS GRANTED TO YOU FOR THE CODE, CLOUDERA IS NOT LIABLE FOR ANY
#  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, PUNITIVE OR
#  CONSEQUENTIAL DAMAGES INCLUDING, BUT NOT LIMITED TO, DAMAGES
#  RELATED TO LOST REVENUE, LOST PROFITS, LOSS OF INCOME, LOSS OF
#  BUSINESS ADVANTAGE OR UNAVAILABILITY, OR LOSS OR CORRUPTION OF
#  DATA.
#
#
############################################################################


# Start with a Base CML Runtime
# Note: This particular image will use the Python base image, not R as expected. There is a
# complication with CML that prevents editors and applications from launching if the CML
# version of python isn't present. This should be fixed in a future release.
FROM docker.repository.cloudera.com/cloudera/cdsw/ml-runtime-workbench-python3.7-standard:2022.04.1-b6

# Updated the images with apt-get
RUN apt-get update
RUN apt install software-properties-common -y
RUN apt-get update && apt-get upgrade -y
RUN apt install r-cran-rstan -y
#RUN add-apt-repository ppa:c2d4u.team/c2d4u4.0+
#RUN add-apt-repository ppa:marutter/c2d4u3.5
RUN apt-get update

# Setup R Repos
RUN apt-get install -y --no-install-recommends software-properties-common dirmngr gdebi-core
RUN curl https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc > /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
RUN add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

# Install R
# Since this Dockerfile uses the CML Python base image, it is necessary to install R. This will
# not install the # cdsw package used for managing experiments and models with R sessions. Given
# that models and # experiments don't use R-Studio as the editor, this is not a problem. Just make
# sure to keep consistency in R versions. The current CML R Runtime uses R 4.0.4, so that is the
# target version to install
RUN apt-get install -y r-base-core=4.0.4-1.2004.0

# Install R Studio
RUN curl -O https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2022.07.0-548-amd64.deb
RUN gdebi -n rstudio-server-2022.07.0-548-amd64.deb

# Configure RStudio to work in CML
# RStudio needs some changes made to the default configuration to work in CML, e.g.
# port and host info. This is set in the two additonal files that are added to the image.

RUN chown -R cdsw:cdsw /var/lib/rstudio-server && chmod -R 777 /var/lib/rstudio-server
COPY rserver.conf /etc/rstudio/rserver.conf
COPY rstudio-cml /usr/local/bin/rstudio-cml
RUN chmod +x /usr/local/bin/rstudio-cml

# Create a Symlink to the default editor launcher
# This is the main requirement to get CML to launch a different editor. Create a symlink
# from the editors launcher to /usr/local/bin/ml-runtime-editor
RUN ln -s /usr/local/bin/rstudio-cml /usr/local/bin/ml-runtime-editor

# Install additional R dependencies
COPY r-runtime-dependencies.txt /build/

RUN \
    apt-get update && \
    cat /build/r-runtime-dependencies.txt | \
      sed '/^$/d; /^#/d; s/#.*$//' | \
      xargs apt-get install -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /build

RUN apt-get -y update && apt-get install -y
RUN apt-get install -y default-jre
RUN apt-get install -y default-jdk
RUN R CMD javareconf 
RUN apt-get install r-cran-rjava

## Setup for rJava
#RUN apt-get -y update && apt-get install -y \
#   r-api-4.0 \
#   default-jdk \
#   r-cran-rjava \
#   && apt-get clean \
#   && rm -rf /var/lib/apt/lists/

# Install rJava
RUN R -e "install.packages(c('rJava'))"

# Change permissions to allow env variables to be pushed to Renviron.site file
# when the rstudio-cml startup file is run
RUN chmod -R 666 /etc/R/Renviron.site

# Set the ENV and LABEL details for this Runtime
# The final requirement is to set various labels and environment variables that CML needs
# to pick up the Runtime's details. Here the editor is to RStudio
ENV ML_RUNTIME_EDITOR="RStudio" \
ML_RUNTIME_EDITION="RStudio Community Runtime BW"	\
ML_RUNTIME_SHORT_VERSION="2022.12" \
ML_RUNTIME_MAINTENANCE_VERSION="1" \
ML_RUNTIME_FULL_VERSION="2022.12.1" \
ML_RUNTIME_DESCRIPTION="RStudio Community Runtime" \
ML_RUNTIME_KERNEL="R 4.0"

LABEL com.cloudera.ml.runtime.editor=$ML_RUNTIME_EDITOR \
com.cloudera.ml.runtime.edition=$ML_RUNTIME_EDITION \
com.cloudera.ml.runtime.full-version=$ML_RUNTIME_FULL_VERSION \
com.cloudera.ml.runtime.short-version=$ML_RUNTIME_SHORT_VERSION \
com.cloudera.ml.runtime.maintenance-version=$ML_RUNTIME_MAINTENANCE_VERSION \
com.cloudera.ml.runtime.description=$ML_RUNTIME_DESCRIPTION \
com.cloudera.ml.runtime.kernel=$ML_RUNTIME_KERNEL
