# basic-htsget
Implementation of htsget using Perl and samtools to do the heavy lifting

# Dependencies

- [bcftools](https://github.com/samtools/bcftools) (any version will do but later is better)
- Perl
- Mojolicious (use `cpanm --installdeps .` to get this)

# Running

## Locally

```
./bin/app.pl daemon
```

Additional help can be got by running

```
./bin/app.pl
```

## Under Hypnotoad

```
APP_PID_FILE=$PWD/app.pid hypnotoad -f $PWD/bin/app.pl
```

## Config

Config can be set using the `MOJO_CONFIG` environment variable or by writing a JSON config file in the path `basic-htsget.json` in the root directory. See [`basic-htsget.json.example`](https://github.com/andrewyatz/basic-htsget/blob/master/basic-htsget.json.example) for an example of the config.

## Additional ENV options

- `APP_PID_FILE` - set this if you are going to run the server with Hypnotoad to locate the PID file
- `APP_LOG_LEVEL` - control the application log level of the application
- `APP_ACCESS_LOG_FILE` - control where the access log is written to (requires [`Mojolicious::Plugins::AccessLog`](https://metacpan.org/pod/Mojolicious::Plugin::AccessLog))
- `APP_ACCESS_LOG_FORMAT` - control the log format. See the AccessLog plugin for more details. Defaults to `combinedio`

# Authorisation

The server has a very dumb authorisation scheme. The token is hard-coded into the config file and is matched against the content of the `Authorization: Bearer XXXXX` HTTP request header. To get bcftools to provide the token you must do the following:

```bash
$ echo -n 'my secret token' > token
$ HTS_AUTH_LOCATION=$PWD/token bcftools view 'https://server/variants/id?referenceName=chr1&start=1&end=100'
```

If you are accessing the server over HTTP then you must set the following environment variable

```bash
HTS_ALLOW_UNENCRYPTED_AUTHORIZATION_HEADER="I understand the risks"
```

## Controlling access

Each VCF file given in the config file can be set to `"public": true` or `"public": false`. If set to false then you must be authorised with the correct token. No other level of access granularity has been given.

# Releasing to Heroku

We have developed a docker image, which can be released to Heroku for testing. This assumes you already have a project to push these assets to in Heroku. For more information see the [Heroku container documentation](https://devcenter.heroku.com/articles/container-registry-and-runtime).

```bash
# Login to heroku
$ heroku login

# Login to the container registry
$ heroku container:login

# Build the image and ignore any local caches (ensure you do rebuild the image)
$ docker build --no-cache

# Push the container
$ heroku container:push web

# Release the container
$ heroku container:release web

# Open in a browser
$ heroku open
```