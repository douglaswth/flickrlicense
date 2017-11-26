# flickrlicense

A thingy to update Flickr photo licenses

## Dependencies

* [Ruby]
  * [Bundler]
* [jQuery]
* [jQuery UI]
* [Concise CSS]
* [Creative Commons Web Font]

[Ruby]: https://www.ruby-lang.org/
[Bundler]: https://bundler.io/
[jQuery]: https://jquery.com/
[jQuery UI]: https://jqueryui.com/
[Concise CSS]: http://concisecss.com/
[Creative Commons Web Font]: https://cc-icons.github.io/

## Setup

Install dependencies:

```bash
bundle install
```

Copy `config.sample.yml` to `config.yml` and replace field values with a [Flickr
API key and secret] and a generated random session secret.

[Flickr API key and secret]: https://www.flickr.com/services/apps/by/me

Start the server:

```bash
bundle exec rackup
```

The app should now be running at [localhost:9292] and you can login with your Flickr account.

[localhost:9292]: http://localhost:9292/
