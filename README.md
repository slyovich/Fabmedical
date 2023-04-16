# Quickstart the workshop

Instead of initializing your own repositroy you can just fork this one to you
own github account.
This repo is a substract of the [Microsoft archived repo](https://github.com/microsoft/MCW-Cloud-native-applications).

## Run locally

### Database

First of all, initialize your database by executing the following commands:

      docker container run --name mongo -p 27017:27017 -d mongo:4.0
      
      #Navigate to your content-init directory
      cd ../content-init

      sudo npm ci
      nodejs server.js

### Backend API

Make sure to get the proper Mongo DB connection string. To do that, get your IP Address where your mongo service is running:

      docker inspect mongo | grep IPAddress

And use the value returned in `IPAddress` to run your backend container

      cd ../content-api
      docker build -t content-api:1.0.0 .
      docker container run --name content-api -p 3001:3001 -e MONGODB_CONNECTION=mongodb://<IPAddress>:27017/contentdb  -d content-api:1.0.0

### Frontend

Make sure to get the proper backend api URL. To do that, get your IP Address where your mongo service is running:

      docker inspect content-api | grep IPAddress

And use the value returned in `IPAddress` to run your backend container

      cd ../content-web
      docker build -t content-web:1.0.0 .
      docker container run --name content-web -p 3000:3000 -e CONTENT_API_URL=http://<IPAddress>:3001 -d content-web:1.0.0