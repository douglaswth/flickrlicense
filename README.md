# flickrlicense

A thingy to update Flickr photo licenses

## Dependencies

* [Ruby]
  * [Bundler]
  * [Flickr Login]
  * [Flickraw]
  * [Sequel]
  * [Sinatra]
* [jQuery]
* [jQuery UI]
* [Concise CSS]
* [Creative Commons Web Font]

[Ruby]: https://www.ruby-lang.org/
[Bundler]: https://bundler.io/
[Flickr Login]: https://github.com/janko-m/flickr-login
[Flickraw]: https://hanklords.github.io/flickraw/
[Sinatra]: http://sinatrarb.com/
[Sequel]: http://sequel.jeremyevans.net/
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

## License

>   flickrlicense -- A thingy to update Flickr photo licenses
>   Copyright (C) 2017  Douglas Thrift
>
>   This program is free software: you can redistribute it and/or modify
>   it under the terms of the GNU Affero General Public License as published
>   by the Free Software Foundation, either version 3 of the License, or
>   (at your option) any later version.
>
>   This program is distributed in the hope that it will be useful,
>   but WITHOUT ANY WARRANTY; without even the implied warranty of
>   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
>   GNU Affero General Public License for more details.
>
>   You should have received a copy of the GNU Affero General Public License
>   along with this program.  If not, see <http://www.gnu.org/licenses/>.
