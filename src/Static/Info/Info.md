> A music player that connects to your cloud/distributed storage.

[Return to the application](/).



## Which services does it use?

Ongaku Ryoho uses two layers of services, these layers are:

1. User layer
2. Music layer


### User layer

This layer will use a service to store data from a user, such as the user's favourites, their playlists and data from the processed music files.

You can choose between these services:

- IndexedDB
- Blockstack
- IPNS (IPFS)


### Music layer

This layer connects with the services the user has on which music can be found. No data is written to these services. You can combine all of the following services:

- Blockstack Storage
- IPFS
- Amazon S3



## How does it work?

Ongaku Ryoho locates all the music files on the given services, extracts the metadata and then stores it via the user layer (which was explained before).


<div id="CORS" />

### CORS

There's only one thing you need to do yourself so that your service will work with the application, and that's setting up [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS) (Cross-Origin Resource Sharing). Here are the instructions you'll need for each service:

#### IPFS

```shell
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs config --json Gateway.HTTPHeaders.Access-Control-Allow-Headers '["X-Requested-With", "Range", "Content-Range"]'
```

#### Amazon S3

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
<CORSRule>
    <AllowedOrigin>*</AllowedOrigin>
    <AllowedMethod>HEAD</AllowedMethod>
    <AllowedMethod>GET</AllowedMethod>
    <MaxAgeSeconds>31536000</MaxAgeSeconds>
    <ExposeHeader>Accept-Ranges</ExposeHeader>
    <ExposeHeader>Content-Encoding</ExposeHeader>
    <ExposeHeader>Content-Length</ExposeHeader>
    <ExposeHeader>Content-Range</ExposeHeader>
    <AllowedHeader>If-Modified-Since</AllowedHeader>
    <AllowedHeader>Origin</AllowedHeader>
    <AllowedHeader>Range</AllowedHeader>
</CORSRule>
</CORSConfiguration>
```
