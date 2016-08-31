FROM perl:5.24-threaded

WORKDIR /app
COPY . /app 
RUN cpanm Carton && carton install

ENTRYPOINT ["carton", "exec", "--", "perl", "marathon_lb_vhost_test.pl"]
