FROM nginx:1.29.0-alpine

# Copy the built SPA assets into nginx web root (so /index.html replaces nginx default page)
COPY dist/angular-k8s-demo/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
