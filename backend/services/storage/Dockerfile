FROM brecheisen/nginx-base:v1

MAINTAINER Ralph Brecheisen <ralph.brecheisen@gmail.com>

COPY nginx-big-upload /usr/local/nginx/modules/nginx-big-upload
COPY nginx.conf /usr/local/nginx/conf/nginx.conf
COPY run.sh /usr/local/nginx/run.sh

WORKDIR /usr/local/nginx

EXPOSE 5002

CMD ["./run.sh"]