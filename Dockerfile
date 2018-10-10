#Grab the latest alpine image
FROM alpine:latest

# Bring in cpanfile
ADD cpanfile /tmp/cpanfile

# Install perl, cpanm and dependencies
RUN apk add --no-cache --update perl perl-dev bash g++ make wget curl libcurl curl-dev zlib zlib-dev gsl gsl-dev bzip2 bzip2-dev libbz2 xz xz-dev && \
  curl -L https://cpanmin.us/ -o /bin/cpanm && \
  chmod +x /bin/cpanm && \
  cd /tmp && \
  cpanm --installdeps --notest . -M https://cpan.metacpan.org && \
  curl -L https://github.com/samtools/bcftools/releases/download/1.9/bcftools-1.9.tar.bz2 -o bcftools-1.9.tar.bz2 && \
  tar xvjf bcftools-1.9.tar.bz2 && \
  cd bcftools-1.9 && \
  ./configure && \
  make && \
  make install && \
  apk del perl-dev g++ make wget curl zlib-dev gsl-dev bzip2-dev xz-dev curl-dev && \
  rm -rf /root/.cpanm/* /usr/local/share/man/* /tmp/cpanfile /tmp/bcftools*

# Add our code
ENV APP_DIR=/opt/webapp
RUN mkdir -p ${APP_DIR}
ADD ./bin ${APP_DIR}/bin
ADD ./lib ${APP_DIR}/lib
ADD ./templates ${APP_DIR}/templates
ADD ./basic-htsget.json.heroku ${APP_DIR}/basic-htsget.json.heroku
WORKDIR ${APP_DIR}

# Setup direcotry and run the image as a non-root user
RUN mkdir -p ${APP_DIR}/tmp
RUN chmod ugo+w ${APP_DIR} ${APP_DIR}/tmp
RUN adduser -D myuser
USER myuser

# Run the app.  CMD is required to run on Heroku
# $PORT is set by Heroku
# ENV APP_ACCESS_LOG_FILE=${APP_DIR}/log/access.log
ENV MOJO_CONFIG=basic-htsget.json.heroku
CMD /opt/webapp/bin/app.pl prefork --listen http://0.0.0.0:${PORT} --pid-file ${APP_DIR}/tmp/prefork.pid -m production --workers 4
