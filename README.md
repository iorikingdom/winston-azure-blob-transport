# winston-azure-blob-transport

[![NPM version](https://badge.fury.io/js/winston-azure-blob-transport.png)](http://badge.fury.io/js/winston-azure-blob-transport)

A [Windows Azure][0] blob storage transport for [winston][1].

##Credit
NOTE: This is a fork of https://github.com/Parsimotion/winston-azure-blob-transport, 99% of the code in this repository was written by user Parsimotion on github.
    This fork simply adds the ability to specify a max file size.

## Installation

``` bash
  $ npm install winston
  $ npm install winston-azure-blob-transport
```

## Usage
``` js
  var winston = require("winston");
  require("winston-azure-blob-transport");

  var logger = new (winston.Logger)({
    transports: [
      new (winston.transports.AzureBlob)({
        account: {
          name: "Azure storage account sub domain ([A-Za-z0-9])",
          key: "The long Azure storage secret key"
        },
        containerName: "A container name",
        blobName: "The name of the blob",
        level: "info"
      })
    ]
  });
  
  logger.warn("Hello!");
```


The Azure transport accepts the following options:

* __level:__ Level of messages that this transport should log (defaults to `info`).
* __account.name:__ The name of the Windows Azure storage account to use
* __account.key:__ The access key used to authenticate into this storage account
* __blobName:__ The name of the blob to log.
* __containerName:__ The container which will contain the logs.
* __maxBlobSize:__ The size in MB when a new blob file should be created.
            Note that the file size may go over the max size. But a  new one will be created within one hour of exceeding the max.

[0]: http://www.windowsazure.com/en-us/develop/nodejs/
[1]: https://github.com/flatiron/winston
