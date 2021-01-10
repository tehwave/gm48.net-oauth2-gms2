# gm48.net OAuth2 for GameMaker Studio 2

Utilize official gm48.net OAuth2 account authentication in GameMaker Studio 2

## Requirements

* YYC (YoYo Compiler)
* GameMaker Studio 2 v2.3.0 or newer
* Windows (other platforms not supported, but may work)
* Client credentials provided from [gm48.net](https://gm48.net)

## Installation

1) Copy and paste the contents of the [gm48_oauth2_library.gml](scripts/gm48_oauth2_library/gm48_oauth2_library.gml) file into a new script resource.

2) Create a new persistent object resource and set up the following events:

**Create**

```gml
gm48_oauth2_init("CLIENT ID", "CLIENT SECRET");
```

The `CLIENT ID` and and `CLIENT SECRET` values must be replaced with your credentials.

These values are made available to you when you create the first leaderboard for your game.

**Step**
```gml
gm48_oauth2_keepalive();
```

**Async HTTP**

```gml
gm48_oauth2_http();
```

**Async Networking**

```gml
gm48_oauth2_networking();
```

### Example project

Download the repository and open the project file in GameMaker Studio 2.

The project will not work out-of-the-box, as the Client ID and Secret credentials provided are not real.

## Usage

Ask the player for authorization to use their gm48.net account.

```gml
gm48_oauth2_authorize(callback);
```

You must provide a script resource to execute when the authorization has finished.

See the [`scr_callback_example`](scripts/scr_callback_example/scr_callback_example.gml) script resource provided.

Once successfully authorized, you now have an Access token stored in the ```gm48_oauth2_access_token``` global variable.

You must use token for authentication to the gm48.net API, and as such, the online leaderboard functionality.

### Scores & Leaderboards

Please refer to the [gm48.net Leaderboards for GameMaker Studio 2 repository](https://github.com/tehwave/gm48.net-leaderboards-gms2) for implementation.

## Security

For any security related issues, please use the form located here: https://gm48.net/contact-us instead of using the issue tracker.

## Changelog

See [CHANGELOG](CHANGELOG.md) for details on what has changed.

## Contributions

See [CONTRIBUTING](CONTRIBUTING.md) for details on how to contribute.

## Credits

- [Peter Jørgensen](https://github.com/tehwave)
- [All Contributors](../../contributors)

Based on [reddit-OAuth2](https://github.com/JujuAdams/reddit-OAuth2) by [Juju Adams](https://github.com/JujuAdams).

## License

[MIT License](LICENSE)
